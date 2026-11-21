import { describe, it, expect, vi, beforeEach } from "vitest";
import { CiyueApiClient, type ApiTransport } from "./client";

describe("CiyueApiClient", () => {
  let client: CiyueApiClient;

  beforeEach(() => {
    client = new CiyueApiClient("http://localhost:47117");
    vi.restoreAllMocks();
  });

  it("getStatus returns server status via fetch", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ status: "ok", app: "Ciyue", port: 47117 }),
      }),
    );

    const res = await client.getStatus();
    expect(res.status).toBe("ok");
    expect(res.app).toBe("Ciyue");
    expect(res.port).toBe(47117);
  });

  it("lookup makes correct request with groupId", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ word: "apple", results: [] }),
    });
    vi.stubGlobal("fetch", mockFetch);

    const res = await client.lookup("apple", 1);
    expect(res.word).toBe("apple");
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:47117/api/lookup?word=apple&groupId=1",
      expect.objectContaining({ method: undefined }),
    );
  });

  it("supports custom ApiTransport", async () => {
    const mockTransport: ApiTransport = {
      fetch: vi.fn().mockResolvedValue({ status: "ok", app: "CiyueCustom", port: 1234 }),
    };
    const customClient = new CiyueApiClient("http://custom-url:1234", mockTransport);

    const res = await customClient.getStatus();
    expect(res.app).toBe("CiyueCustom");
    expect(mockTransport.fetch).toHaveBeenCalledWith("http://custom-url:1234/api/status");
  });

  it("handles wordbook operations", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ stared: true }),
    });
    vi.stubGlobal("fetch", mockFetch);

    const stared = await client.checkWordbook("test");
    expect(stared).toBe(true);

    await client.addToWordbook("test");
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:47117/api/wordbook?word=test",
      expect.objectContaining({
        method: "POST",
      }),
    );
  });
});

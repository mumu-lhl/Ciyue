import { describe, it, expect, vi, beforeEach } from "vitest";
import { CiyueWebApiClient } from "./client";

describe("CiyueWebApiClient", () => {
  let client: CiyueWebApiClient;

  beforeEach(() => {
    client = new CiyueWebApiClient("http://localhost:47117");
    vi.restoreAllMocks();
  });

  it("getStatus returns server status", async () => {
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

  it("lookup makes correct request", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ word: "apple", results: [] }),
    });
    vi.stubGlobal("fetch", mockFetch);

    const res = await client.lookup("apple", 1);
    expect(res.word).toBe("apple");
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:47117/api/lookup?word=apple&groupId=1",
    );
  });
});

import { describe, it, expect, vi, beforeEach } from "vitest";
import { CiyueApiClient } from "./client";
import * as messaging from "../utils/messaging";

describe("CiyueApiClient", () => {
  let client: CiyueApiClient;

  beforeEach(() => {
    client = new CiyueApiClient("http://127.0.0.1:47117");
    vi.restoreAllMocks();
  });

  it("normalizes server url trailing slash", () => {
    client.setServerUrl("http://127.0.0.1:47117///");
    // @ts-expect-error private field access for test
    expect(client.serverUrl).toBe("http://127.0.0.1:47117");
  });

  it("calls lookup endpoint via proxyFetch", async () => {
    const mockLookupRes = {
      word: "hello",
      results: [],
      stared: false,
    };

    const spy = vi.spyOn(messaging, "proxyFetch").mockResolvedValue(mockLookupRes);

    const result = await client.lookup("hello");
    expect(spy).toHaveBeenCalledWith({
      url: "http://127.0.0.1:47117/api/lookup?word=hello",
    });
    expect(result).toEqual(mockLookupRes);
  });

  it("handles wordbook check returning false on error", async () => {
    vi.spyOn(messaging, "proxyFetch").mockRejectedValue(new Error("Network error"));
    const isStared = await client.checkWordbook("test");
    expect(isStared).toBe(false);
  });
});

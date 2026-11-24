import { describe, it, expect, vi, beforeEach } from "vitest";
import { fakeBrowser } from "wxt/testing/fake-browser";
import { handleProxyFetch } from "../entrypoints/background";

describe("background service worker", () => {
  beforeEach(() => {
    fakeBrowser.reset();
    vi.restoreAllMocks();
  });

  describe("handleProxyFetch", () => {
    it("returns JSON data when response is 200 with application/json", async () => {
      const mockData = { word: "apple", results: [] };
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({
          ok: true,
          status: 200,
          headers: new Headers({
            "content-type": "application/json; charset=utf-8",
          }),
          json: async () => mockData,
        }),
      );

      const res = await handleProxyFetch({
        url: "http://127.0.0.1:47117/api/lookup",
      });
      expect(res).toEqual({
        ok: true,
        status: 200,
        data: mockData,
      });
    });

    it("returns text data when response is not JSON", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({
          ok: true,
          status: 200,
          headers: new Headers({ "content-type": "text/plain" }),
          text: async () => "pong",
        }),
      );

      const res = await handleProxyFetch({
        url: "http://127.0.0.1:47117/ping",
      });
      expect(res).toEqual({
        ok: true,
        status: 200,
        data: "pong",
      });
    });

    it("extracts custom error message when response is 400 with error JSON", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({
          ok: false,
          status: 400,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ error: "Invalid word parameter" }),
        }),
      );

      const res = await handleProxyFetch({
        url: "http://127.0.0.1:47117/api/lookup",
      });
      expect(res).toEqual({
        ok: false,
        status: 400,
        error: "Invalid word parameter",
      });
    });

    it("falls back to HTTP status when response is not JSON and fails", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({
          ok: false,
          status: 502,
          headers: new Headers({ "content-type": "text/html" }),
          text: async () => "Bad Gateway",
        }),
      );

      const res = await handleProxyFetch({
        url: "http://127.0.0.1:47117/api/lookup",
      });
      expect(res).toEqual({
        ok: false,
        status: 502,
        error: "HTTP 502",
      });
    });

    it("catches network errors and returns friendly error message", async () => {
      vi.stubGlobal(
        "fetch",
        vi
          .fn()
          .mockRejectedValue(new Error("Failed to connect to localhost:47117")),
      );

      const res = await handleProxyFetch({
        url: "http://127.0.0.1:47117/api/lookup",
      });
      expect(res.ok).toBe(false);
      expect(res.status).toBe(0);
      expect(res.error).toBe("Failed to connect to localhost:47117");
    });
  });
});

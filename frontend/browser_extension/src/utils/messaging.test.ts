import { describe, it, expect, vi, beforeEach } from "vitest";
import { fakeBrowser } from "wxt/testing/fake-browser";
import { proxyFetch, createAiStream } from "./messaging";

describe("messaging utilities", () => {
  beforeEach(() => {
    fakeBrowser.reset();
    vi.restoreAllMocks();
  });

  describe("proxyFetch", () => {
    it("returns data when background proxy responds with ok: true", async () => {
      (vi.spyOn(chrome.runtime, "sendMessage") as any).mockResolvedValue({
        ok: true,
        status: 200,
        data: { word: "apple", results: [] },
      });

      const res = await proxyFetch({ url: "http://127.0.0.1:47117/api/lookup?word=apple" });
      expect(res).toEqual({ word: "apple", results: [] });
    });

    it("throws error when background returns no response", async () => {
      (vi.spyOn(chrome.runtime, "sendMessage") as any).mockResolvedValue(null);

      await expect(proxyFetch({ url: "http://127.0.0.1:47117/api/status" })).rejects.toThrow(
        "未收到后台响应，请检查扩展后台状态",
      );
    });

    it("throws error with background error message on failure", async () => {
      (vi.spyOn(chrome.runtime, "sendMessage") as any).mockResolvedValue({
        ok: false,
        status: 500,
        error: "服务内部错误",
      });

      await expect(proxyFetch({ url: "http://127.0.0.1:47117/api/status" })).rejects.toThrow(
        "服务内部错误",
      );
    });

    it("throws HTTP status error message if error string is empty", async () => {
      (vi.spyOn(chrome.runtime, "sendMessage") as any).mockResolvedValue({
        ok: false,
        status: 404,
      });

      await expect(proxyFetch({ url: "http://127.0.0.1:47117/api/unknown" })).rejects.toThrow(
        "请求失败 (HTTP 404)",
      );
    });
  });

  describe("createAiStream", () => {
    it("establishes long-lived port and streams chunks to onChunk", () => {
      const messageListeners: ((msg: any) => void)[] = [];
      const disconnectListeners: (() => void)[] = [];

      const mockPort = {
        postMessage: vi.fn(),
        disconnect: vi.fn(),
        onMessage: {
          addListener: vi.fn((fn) => messageListeners.push(fn)),
        },
        onDisconnect: {
          addListener: vi.fn((fn) => disconnectListeners.push(fn)),
        },
      };

      vi.spyOn(chrome.runtime, "connect").mockReturnValue(mockPort as any);

      const onChunk = vi.fn();
      const onError = vi.fn();
      const onDone = vi.fn();

      const cancel = createAiStream(
        { mode: "explain", text: "test", serverUrl: "http://127.0.0.1:47117" },
        onChunk,
        onError,
        onDone,
      );

      expect(chrome.runtime.connect).toHaveBeenCalledWith({ name: "ai-stream" });
      expect(mockPort.postMessage).toHaveBeenCalledWith({
        mode: "explain",
        text: "test",
        serverUrl: "http://127.0.0.1:47117",
      });

      // Deliver message chunks
      messageListeners.forEach((listener) => {
        listener({ chunk: "Hello " });
        listener({ chunk: "World!" });
      });

      expect(onChunk).toHaveBeenCalledWith("Hello ");
      expect(onChunk).toHaveBeenCalledWith("World!");

      // Complete stream
      messageListeners.forEach((listener) => {
        listener({ done: true });
      });

      expect(onDone).toHaveBeenCalled();
      expect(mockPort.disconnect).toHaveBeenCalled();

      // Test cancel
      cancel();
    });

    it("calls onError when stream receives an error payload", () => {
      const messageListeners: ((msg: any) => void)[] = [];

      const mockPort = {
        postMessage: vi.fn(),
        disconnect: vi.fn(),
        onMessage: {
          addListener: vi.fn((fn) => messageListeners.push(fn)),
        },
        onDisconnect: {
          addListener: vi.fn(),
        },
      };

      vi.spyOn(chrome.runtime, "connect").mockReturnValue(mockPort as any);

      const onChunk = vi.fn();
      const onError = vi.fn();
      const onDone = vi.fn();

      createAiStream(
        { mode: "translate", text: "hello", serverUrl: "http://127.0.0.1:47117" },
        onChunk,
        onError,
        onDone,
      );

      messageListeners.forEach((listener) => {
        listener({ error: "AI 服务未配置" });
      });

      expect(onError).toHaveBeenCalledWith("AI 服务未配置");
    });

    it("calls onError if port disconnects with runtime lastError", () => {
      const disconnectListeners: (() => void)[] = [];

      const mockPort = {
        postMessage: vi.fn(),
        disconnect: vi.fn(),
        onMessage: {
          addListener: vi.fn(),
        },
        onDisconnect: {
          addListener: vi.fn((fn) => disconnectListeners.push(fn)),
        },
      };

      vi.spyOn(chrome.runtime, "connect").mockReturnValue(mockPort as any);

      const onChunk = vi.fn();
      const onError = vi.fn();
      const onDone = vi.fn();

      createAiStream(
        { mode: "translate", text: "test", serverUrl: "http://127.0.0.1:47117" },
        onChunk,
        onError,
        onDone,
      );

      // Simulate chrome.runtime.lastError on disconnect
      (chrome.runtime as any).lastError = { message: "Extension context invalidated" };

      disconnectListeners.forEach((listener) => listener());

      expect(onError).toHaveBeenCalledWith("Extension context invalidated");
      delete (chrome.runtime as any).lastError;
    });
  });
});

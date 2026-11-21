import { defineBackground } from "wxt/utils/define-background";
import type { ProxyFetchRequest, ProxyFetchResponse } from "../api/types";

export default defineBackground(() => {
  chrome.runtime.onInstalled.addListener(() => {
    chrome.contextMenus.create({
      id: "ciyue-search-selection",
      title: '在词悦中查询 "%s"',
      contexts: ["selection"],
    });
  });

  chrome.contextMenus.onClicked.addListener((info, tab) => {
    if (info.menuItemId === "ciyue-search-selection" && info.selectionText) {
      if (tab?.id) {
        chrome.tabs.sendMessage(tab.id, {
          type: "CIYUE_LOOKUP",
          word: info.selectionText.trim(),
        });
      }
    }
  });

  chrome.commands.onCommand.addListener(async (command) => {
    if (command === "lookup-selection") {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab?.id) {
        chrome.tabs.sendMessage(tab.id, {
          type: "CIYUE_TRIGGER_HOTKEY",
        });
      }
    }
  });

  // Handle Proxy Fetch to eliminate Mixed Content and CSP issues on HTTPS websites
  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message.type === "PROXY_FETCH") {
      const req: ProxyFetchRequest = message.payload;
      handleProxyFetch(req).then(sendResponse);
      return true; // Keep channel open for async response
    }
  });

  // Handle SSE streaming via long-lived Chrome Port
  chrome.runtime.onConnect.addListener((port) => {
    if (port.name !== "ai-stream") return;

    let aborted = false;
    let reader: ReadableStreamDefaultReader<Uint8Array> | null = null;

    port.onDisconnect.addListener(() => {
      aborted = true;
      if (reader) {
        reader.cancel().catch(() => {});
      }
    });

    port.onMessage.addListener(
      async (msg: { mode: "explain" | "translate"; text: string; serverUrl: string }) => {
        const { mode, text, serverUrl } = msg;
        const cleanUrl = serverUrl.replace(/\/+$/, "");
        const endpoint =
          mode === "translate"
            ? `${cleanUrl}/api/ai/translate?text=${encodeURIComponent(text)}&stream=true`
            : `${cleanUrl}/api/ai/explain?word=${encodeURIComponent(text)}&stream=true`;

        try {
          const res = await fetch(endpoint);
          if (!res.ok) {
            let errMsg = `HTTP ${res.status}`;
            try {
              const errJson = await res.json();
              if (errJson.error) errMsg = errJson.error;
            } catch {}
            port.postMessage({ error: errMsg });
            port.postMessage({ done: true });
            return;
          }

          if (!res.body) {
            port.postMessage({ error: "响应流为空" });
            port.postMessage({ done: true });
            return;
          }

          reader = res.body.getReader();
          const decoder = new TextDecoder();
          let buffer = "";

          while (!aborted) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split("\n\n");
            buffer = lines.pop() || "";

            for (const line of lines) {
              if (line.startsWith("data: ")) {
                const payload = line.substring(6).trim();
                if (payload === "[DONE]") {
                  port.postMessage({ done: true });
                  return;
                }
                try {
                  const parsed = JSON.parse(payload);
                  if (parsed.chunk) {
                    port.postMessage({ chunk: parsed.chunk });
                  }
                } catch {}
              }
            }
          }

          if (!aborted) {
            port.postMessage({ done: true });
          }
        } catch (err: any) {
          if (!aborted) {
            port.postMessage({ error: err.message || "网络连接异常" });
            port.postMessage({ done: true });
          }
        }
      },
    );
  });
});

export async function handleProxyFetch(req: ProxyFetchRequest): Promise<ProxyFetchResponse> {
  try {
    const res = await fetch(req.url, {
      method: req.method || "GET",
      headers: req.headers,
      body: req.body ? JSON.stringify(req.body) : undefined,
    });

    const contentType = res.headers.get("content-type") || "";
    let data: any;
    if (contentType.includes("application/json")) {
      data = await res.json();
    } else {
      data = await res.text();
    }

    if (!res.ok) {
      const errMsg = data && data.error ? data.error : `HTTP ${res.status}`;
      return { ok: false, status: res.status, error: errMsg };
    }

    return { ok: true, status: res.status, data };
  } catch (err: any) {
    return {
      ok: false,
      status: 0,
      error: err.message || "无法连接到词悦桌面端，请确认服务已开启",
    };
  }
}

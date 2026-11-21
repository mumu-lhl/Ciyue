import type { ProxyFetchRequest, ProxyFetchResponse, StreamChunkMessage } from '../api/types';

export async function proxyFetch<T = any>(req: ProxyFetchRequest): Promise<T> {
  const res = (await chrome.runtime.sendMessage({
    type: 'PROXY_FETCH',
    payload: req,
  })) as ProxyFetchResponse<T>;

  if (!res) {
    throw new Error('未收到后台响应，请检查扩展后台状态');
  }

  if (!res.ok) {
    throw new Error(res.error || `请求失败 (HTTP ${res.status})`);
  }

  return res.data as T;
}

export function createAiStream(
  payload: { mode: 'explain' | 'translate'; text: string; serverUrl: string },
  onChunk: (chunk: string) => void,
  onError: (err: string) => void,
  onDone: () => void,
): () => void {
  const port = chrome.runtime.connect({ name: 'ai-stream' });

  port.onMessage.addListener((msg: StreamChunkMessage) => {
    if (msg.error) {
      onError(msg.error);
    } else if (msg.chunk) {
      onChunk(msg.chunk);
    }
    if (msg.done) {
      onDone();
      port.disconnect();
    }
  });

  port.onDisconnect.addListener(() => {
    if (chrome.runtime.lastError) {
      onError(chrome.runtime.lastError.message || '连接断开');
    }
  });

  port.postMessage(payload);

  return () => {
    try {
      port.disconnect();
    } catch (_) {}
  };
}

export function fetchSseStream(
  url: string,
  options: RequestInit,
  onChunk: (chunk: string) => void,
  onError: (error: string) => void,
  onDone: () => void,
): () => void {
  const controller = new AbortController();

  (async () => {
    try {
      const res = await fetch(url, {
        ...options,
        signal: controller.signal,
      });

      if (!res.ok) {
        let errMsg = `HTTP ${res.status}`;
        try {
          const json = await res.json();
          if (json.error) errMsg = json.error;
        } catch {
          // ignore
        }
        onError(errMsg);
        return;
      }

      const reader = res.body?.getReader();
      if (!reader) {
        onError("Stream body not available");
        return;
      }

      const decoder = new TextDecoder();
      let buffer = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n\n");
        buffer = lines.pop() ?? "";

        for (const line of lines) {
          if (line.startsWith("data: ")) {
            const payload = line.substring(6).trim();
            if (payload === "[DONE]") {
              onDone();
              return;
            }
            try {
              const parsed = JSON.parse(payload);
              if (parsed.error) {
                onError(parsed.error);
                return;
              }
              if (parsed.chunk) {
                onChunk(parsed.chunk);
              }
            } catch {
              // ignore malformed chunks
            }
          }
        }
      }
      onDone();
    } catch (e: any) {
      if (controller.signal.aborted) return;
      onError(e?.message ?? "Network error");
    }
  })();

  return () => {
    controller.abort();
  };
}

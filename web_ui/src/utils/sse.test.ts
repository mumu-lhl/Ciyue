import { describe, it, expect, vi } from "vitest";
import { fetchSseStream } from "./sse";

describe("fetchSseStream", () => {
  it("handles stream chunks correctly", async () => {
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      start(controller) {
        controller.enqueue(encoder.encode('data: {"chunk":"Hello "}\n\n'));
        controller.enqueue(encoder.encode('data: {"chunk":"World!"}\n\n'));
        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
        controller.close();
      },
    });

    const mockResponse = new Response(stream, { status: 200 });
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(mockResponse));

    let accumulated = "";
    let doneCalled = false;

    await new Promise<void>((resolve) => {
      fetchSseStream(
        "/api/test",
        {},
        (chunk) => {
          accumulated += chunk;
        },
        () => {},
        () => {
          doneCalled = true;
          resolve();
        },
      );
    });

    expect(accumulated).toBe("Hello World!");
    expect(doneCalled).toBe(true);
    vi.unstubAllGlobals();
  });
});

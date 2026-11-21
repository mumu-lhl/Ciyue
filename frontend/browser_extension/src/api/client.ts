import {
  CiyueApiClient as BaseCiyueApiClient,
  type ApiTransport,
  type ProxyFetchRequest,
} from "@ciyue/shared";
import { proxyFetch } from "../utils/messaging";

export class ExtensionApiTransport implements ApiTransport {
  async fetch<T>(
    url: string,
    options?: { method?: string; body?: any; headers?: Record<string, string> },
  ): Promise<T> {
    const req: ProxyFetchRequest = { url };
    if (options?.method) req.method = options.method;
    if (options?.headers) req.headers = options.headers;
    if (options?.body !== undefined) req.body = options.body;
    return proxyFetch<T>(req);
  }
}

export class CiyueApiClient extends BaseCiyueApiClient {
  constructor(serverUrl: string) {
    super(serverUrl, new ExtensionApiTransport());
  }
}

import type {
  GroupItem,
  LookupResponse,
  ServerStatus,
  SuggestResponse,
} from "./types";

export interface ApiTransport {
  fetch<T>(
    url: string,
    options?: { method?: string; body?: any; headers?: Record<string, string> },
  ): Promise<T>;
}

export class FetchApiTransport implements ApiTransport {
  async fetch<T>(
    url: string,
    options?: { method?: string; body?: any; headers?: Record<string, string> },
  ): Promise<T> {
    const init: RequestInit = {
      method: options?.method,
      headers: {
        ...(options?.body !== undefined
          ? { "Content-Type": "application/json" }
          : {}),
        ...options?.headers,
      },
    };
    if (options?.body !== undefined) {
      init.body = JSON.stringify(options.body);
    }
    const res = await fetch(url, init);
    if (!res.ok) {
      throw new Error(`Request to ${url} failed: HTTP ${res.status}`);
    }
    return res.json();
  }
}

export class CiyueApiClient {
  serverUrl: string;
  protected transport: ApiTransport;

  constructor(serverUrl = "", transport?: ApiTransport) {
    this.serverUrl = serverUrl.replace(/\/+$/, "");
    this.transport = transport ?? new FetchApiTransport();
  }

  setServerUrl(url: string): void {
    this.serverUrl = url.replace(/\/+$/, "");
  }

  getServerUrl(): string {
    return this.serverUrl;
  }

  private url(endpoint: string): string {
    return `${this.serverUrl}${endpoint}`;
  }

  async getStatus(): Promise<ServerStatus> {
    return this.transport.fetch<ServerStatus>(this.url("/api/status"));
  }

  async getGroups(): Promise<GroupItem[]> {
    return this.transport.fetch<GroupItem[]>(this.url("/api/groups"));
  }

  async switchGroup(id: number | string): Promise<void> {
    await this.transport.fetch(
      this.url(`/api/groups/switch?id=${encodeURIComponent(id)}`),
      {
        method: "POST",
      },
    );
  }

  async getSuggestions(query: string): Promise<SuggestResponse> {
    return this.transport.fetch<SuggestResponse>(
      this.url(`/api/suggest?q=${encodeURIComponent(query)}`),
    );
  }

  async lookup(
    word: string,
    groupId?: number | string,
  ): Promise<LookupResponse> {
    let endpoint = `/api/lookup?word=${encodeURIComponent(word)}`;
    if (groupId !== undefined) {
      endpoint += `&groupId=${encodeURIComponent(groupId)}`;
    }
    return this.transport.fetch<LookupResponse>(this.url(endpoint));
  }

  async checkWordbook(word: string): Promise<boolean> {
    try {
      const data = await this.transport.fetch<{ stared: boolean }>(
        this.url(`/api/wordbook/check?word=${encodeURIComponent(word)}`),
      );
      return !!data?.stared;
    } catch {
      return false;
    }
  }

  async addToWordbook(word: string): Promise<void> {
    await this.transport.fetch(
      this.url(`/api/wordbook?word=${encodeURIComponent(word)}`),
      {
        method: "POST",
      },
    );
  }

  async removeFromWordbook(word: string): Promise<void> {
    await this.transport.fetch(
      this.url(`/api/wordbook?word=${encodeURIComponent(word)}`),
      {
        method: "DELETE",
      },
    );
  }
}

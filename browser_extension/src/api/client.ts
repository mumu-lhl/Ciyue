import type { GroupItem, LookupResponse, ServerStatus, SuggestResponse } from "./types";
import { proxyFetch } from "../utils/messaging";

export class CiyueApiClient {
  constructor(private serverUrl: string) {}

  setServerUrl(url: string) {
    this.serverUrl = url.replace(/\/+$/, "");
  }

  async getStatus(): Promise<ServerStatus> {
    return proxyFetch<ServerStatus>({
      url: `${this.serverUrl}/api/status`,
    });
  }

  async getGroups(): Promise<GroupItem[]> {
    return proxyFetch<GroupItem[]>({
      url: `${this.serverUrl}/api/groups`,
    });
  }

  async switchGroup(id: string): Promise<void> {
    await proxyFetch({
      url: `${this.serverUrl}/api/groups/switch?id=${encodeURIComponent(id)}`,
      method: "POST",
    });
  }

  async getSuggestions(query: string): Promise<SuggestResponse> {
    return proxyFetch<SuggestResponse>({
      url: `${this.serverUrl}/api/suggest?q=${encodeURIComponent(query)}`,
    });
  }

  async lookup(word: string): Promise<LookupResponse> {
    return proxyFetch<LookupResponse>({
      url: `${this.serverUrl}/api/lookup?word=${encodeURIComponent(word)}`,
    });
  }

  async checkWordbook(word: string): Promise<boolean> {
    try {
      const res = await proxyFetch<{ stared: boolean }>({
        url: `${this.serverUrl}/api/wordbook/check?word=${encodeURIComponent(word)}`,
      });
      return !!res.stared;
    } catch {
      return false;
    }
  }

  async addToWordbook(word: string): Promise<void> {
    await proxyFetch({
      url: `${this.serverUrl}/api/wordbook?word=${encodeURIComponent(word)}`,
      method: "POST",
    });
  }

  async removeFromWordbook(word: string): Promise<void> {
    await proxyFetch({
      url: `${this.serverUrl}/api/wordbook?word=${encodeURIComponent(word)}`,
      method: "DELETE",
    });
  }
}

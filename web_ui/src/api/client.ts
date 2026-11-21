import type { GroupItem, LookupResponse, ServerStatus, SuggestResponse } from "./types";

export class CiyueWebApiClient {
  private baseUrl: string;

  constructor(baseUrl = "") {
    this.baseUrl = baseUrl.replace(/\/+$/, "");
  }

  private url(endpoint: string): string {
    return `${this.baseUrl}${endpoint}`;
  }

  async getStatus(): Promise<ServerStatus> {
    const res = await fetch(this.url("/api/status"));
    if (!res.ok) throw new Error(`Status check failed: HTTP ${res.status}`);
    return res.json();
  }

  async getGroups(): Promise<GroupItem[]> {
    const res = await fetch(this.url("/api/groups"));
    if (!res.ok) throw new Error(`Failed to load groups: HTTP ${res.status}`);
    return res.json();
  }

  async switchGroup(id: number | string): Promise<void> {
    const res = await fetch(this.url(`/api/groups/switch?id=${encodeURIComponent(id)}`), {
      method: "POST",
    });
    if (!res.ok) throw new Error(`Failed to switch group: HTTP ${res.status}`);
  }

  async getSuggestions(query: string): Promise<SuggestResponse> {
    const res = await fetch(this.url(`/api/suggest?q=${encodeURIComponent(query)}`));
    if (!res.ok) throw new Error(`Failed to fetch suggestions: HTTP ${res.status}`);
    return res.json();
  }

  async lookup(word: string, groupId?: number | string): Promise<LookupResponse> {
    let endpoint = `/api/lookup?word=${encodeURIComponent(word)}`;
    if (groupId !== undefined) {
      endpoint += `&groupId=${encodeURIComponent(groupId)}`;
    }
    const res = await fetch(this.url(endpoint));
    if (!res.ok) throw new Error(`Lookup failed: HTTP ${res.status}`);
    return res.json();
  }

  async checkWordbook(word: string): Promise<boolean> {
    const res = await fetch(this.url(`/api/wordbook/check?word=${encodeURIComponent(word)}`));
    if (!res.ok) return false;
    const data = await res.json();
    return !!data.stared;
  }

  async addToWordbook(word: string): Promise<void> {
    const res = await fetch(this.url(`/api/wordbook?word=${encodeURIComponent(word)}`), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ word }),
    });
    if (!res.ok) throw new Error(`Failed to add to wordbook: HTTP ${res.status}`);
  }

  async removeFromWordbook(word: string): Promise<void> {
    const res = await fetch(this.url(`/api/wordbook?word=${encodeURIComponent(word)}`), {
      method: "DELETE",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ word }),
    });
    if (!res.ok) throw new Error(`Failed to remove from wordbook: HTTP ${res.status}`);
  }
}

export const api = new CiyueWebApiClient();

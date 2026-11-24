import { describe, it, expect, vi, beforeEach } from "vitest";
import { CiyueApiClient } from "./client";
import * as messaging from "../utils/messaging";

describe("CiyueApiClient", () => {
  let client: CiyueApiClient;

  beforeEach(() => {
    client = new CiyueApiClient("http://127.0.0.1:47117");
    vi.restoreAllMocks();
  });

  it("normalizes server url trailing slash", () => {
    client.setServerUrl("http://127.0.0.1:47117///");
    expect(client.serverUrl).toBe("http://127.0.0.1:47117");
  });

  it("fetches server status via getStatus", async () => {
    const mockStatus = {
      status: "ok",
      app: "Ciyue",
      port: 47117,
      allowLan: false,
      currentGroupId: "default",
      dictionariesCount: 5,
    };
    const spy = vi.spyOn(messaging, "proxyFetch").mockResolvedValue(mockStatus);

    const res = await client.getStatus();
    expect(spy).toHaveBeenCalledWith({
      url: "http://127.0.0.1:47117/api/status",
    });
    expect(res).toEqual(mockStatus);
  });

  it("fetches dictionary groups via getGroups", async () => {
    const mockGroups = [
      { id: "g1", name: "English", isCurrent: true, dictCount: 3 },
      { id: "g2", name: "Japanese", isCurrent: false, dictCount: 2 },
    ];
    const spy = vi.spyOn(messaging, "proxyFetch").mockResolvedValue(mockGroups);

    const res = await client.getGroups();
    expect(spy).toHaveBeenCalledWith({
      url: "http://127.0.0.1:47117/api/groups",
    });
    expect(res).toEqual(mockGroups);
  });

  it("switches current dictionary group via switchGroup", async () => {
    const spy = vi
      .spyOn(messaging, "proxyFetch")
      .mockResolvedValue({ success: true });

    await client.switchGroup("g2");
    expect(spy).toHaveBeenCalledWith({
      url: "http://127.0.0.1:47117/api/groups/switch?id=g2",
      method: "POST",
    });
  });

  it("fetches search suggestions via getSuggestions", async () => {
    const mockSuggestions = {
      query: "app",
      dictionarySuggestions: ["apple", "apply"],
      spellingSuggestions: [],
    };
    const spy = vi
      .spyOn(messaging, "proxyFetch")
      .mockResolvedValue(mockSuggestions);

    const res = await client.getSuggestions("app");
    expect(spy).toHaveBeenCalledWith({
      url: "http://127.0.0.1:47117/api/suggest?q=app",
    });
    expect(res).toEqual(mockSuggestions);
  });

  it("calls lookup endpoint via proxyFetch", async () => {
    const mockLookupRes = {
      word: "hello",
      results: [],
      stared: false,
    };

    const spy = vi
      .spyOn(messaging, "proxyFetch")
      .mockResolvedValue(mockLookupRes);

    const result = await client.lookup("hello");
    expect(spy).toHaveBeenCalledWith({
      url: "http://127.0.0.1:47117/api/lookup?word=hello",
    });
    expect(result).toEqual(mockLookupRes);
  });

  it("checks wordbook status accurately", async () => {
    const spy = vi
      .spyOn(messaging, "proxyFetch")
      .mockResolvedValue({ stared: true });
    const isStared = await client.checkWordbook("star");
    expect(spy).toHaveBeenCalledWith({
      url: "http://127.0.0.1:47117/api/wordbook/check?word=star",
    });
    expect(isStared).toBe(true);
  });

  it("handles wordbook check returning false on error", async () => {
    vi.spyOn(messaging, "proxyFetch").mockRejectedValue(
      new Error("Network error"),
    );
    const isStared = await client.checkWordbook("test");
    expect(isStared).toBe(false);
  });

  it("adds word to wordbook via addToWordbook", async () => {
    const spy = vi
      .spyOn(messaging, "proxyFetch")
      .mockResolvedValue({ success: true });
    await client.addToWordbook("galaxy");
    expect(spy).toHaveBeenCalledWith({
      url: "http://127.0.0.1:47117/api/wordbook?word=galaxy",
      method: "POST",
    });
  });

  it("removes word from wordbook via removeFromWordbook", async () => {
    const spy = vi
      .spyOn(messaging, "proxyFetch")
      .mockResolvedValue({ success: true });
    await client.removeFromWordbook("galaxy");
    expect(spy).toHaveBeenCalledWith({
      url: "http://127.0.0.1:47117/api/wordbook?word=galaxy",
      method: "DELETE",
    });
  });
});

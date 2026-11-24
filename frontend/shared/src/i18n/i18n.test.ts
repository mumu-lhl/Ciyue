import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import {
  t,
  resolveLocale,
  getStoredLocale,
  setStoredLocale,
  zh,
  en,
  type TranslationKey,
} from "./index";

describe("i18n utilities", () => {
  const store = new Map<string, string>();
  const mockStorage = {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, val: string) => store.set(key, String(val)),
    removeItem: (key: string) => store.delete(key),
    clear: () => store.clear(),
  };

  beforeEach(() => {
    store.clear();
    vi.stubGlobal("localStorage", mockStorage);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("has exact key parity between zh and en translations", () => {
    function getKeys(obj: any, prefix = ""): string[] {
      let keys: string[] = [];
      for (const [k, v] of Object.entries(obj)) {
        const fullKey = prefix ? `${prefix}.${k}` : k;
        if (typeof v === "object" && v !== null) {
          keys = keys.concat(getKeys(v, fullKey));
        } else {
          keys.push(fullKey);
        }
      }
      return keys.sort();
    }

    const zhKeys = getKeys(zh);
    const enKeys = getKeys(en);

    expect(zhKeys).toEqual(enKeys);
  });

  it("resolves auto locale using navigator.language", () => {
    vi.stubGlobal("navigator", { language: "zh-CN" });
    expect(resolveLocale("auto")).toBe("zh");

    vi.stubGlobal("navigator", { language: "en-US" });
    expect(resolveLocale("auto")).toBe("en");

    vi.stubGlobal("navigator", { language: "fr-FR" });
    expect(resolveLocale("auto")).toBe("en");
  });

  it("returns explicit locale when provided", () => {
    expect(resolveLocale("zh")).toBe("zh");
    expect(resolveLocale("en")).toBe("en");
  });

  it("translates text in Chinese and English correctly", () => {
    expect(t("common.search", undefined, "zh")).toBe("查询");
    expect(t("common.search", undefined, "en")).toBe("Search");
  });

  it("interpolates parameters properly", () => {
    expect(t("lookup.searchingWord", { word: "apple" }, "zh")).toBe("正在查询 “apple”...");
    expect(t("lookup.searchingWord", { word: "apple" }, "en")).toBe("Searching “apple”...");
    expect(t("lookup.dictCount", { count: 3 }, "en")).toBe("Found 3 dictionary results");
  });

  it("falls back to key if translation key does not exist", () => {
    // @ts-expect-error testing invalid key
    expect(t("non.existent.key", undefined, "en")).toBe("non.existent.key");
  });

  it("stores and retrieves locale preference correctly", () => {
    expect(getStoredLocale()).toBe("auto");
    setStoredLocale("en");
    expect(getStoredLocale()).toBe("en");
    setStoredLocale("zh");
    expect(getStoredLocale()).toBe("zh");
  });
});

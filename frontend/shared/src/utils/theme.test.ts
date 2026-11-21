import { describe, it, expect, beforeEach, vi } from "vitest";
import {
  THEME_OPTIONS,
  getStoredThemeColor,
  getStoredThemeMode,
  setStoredThemeColor,
  setStoredThemeMode,
} from "./theme";

describe("theme utilities", () => {
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

  it("has blue as the first theme option", () => {
    expect(THEME_OPTIONS[0]?.id).toBe("blue");
  });

  it("provides safe default mode and color when storage is empty", () => {
    expect(getStoredThemeMode()).toBe("auto");
    expect(getStoredThemeColor()).toBe("blue");
  });

  it("stores and retrieves theme mode and color correctly", () => {
    setStoredThemeMode("dark");
    expect(getStoredThemeMode()).toBe("dark");

    setStoredThemeColor("emerald");
    expect(getStoredThemeColor()).toBe("emerald");
  });
});

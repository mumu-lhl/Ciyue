import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import {
  THEME_OPTIONS,
  applyThemeColor,
  applyThemeMode,
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

  afterEach(() => {
    vi.unstubAllGlobals();
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

  it("applies theme color to custom element via applyThemeColor", () => {
    const el = {
      setAttribute: vi.fn(),
    } as unknown as HTMLElement;
    applyThemeColor("violet", el);
    expect(el.setAttribute).toHaveBeenCalledWith("data-theme", "violet");
  });

  it("applies theme color to document.documentElement when rootElement is omitted", () => {
    const mockDocElement = {
      setAttribute: vi.fn(),
    };
    vi.stubGlobal("document", { documentElement: mockDocElement });
    applyThemeColor("rose");
    expect(mockDocElement.setAttribute).toHaveBeenCalledWith("data-theme", "rose");
  });

  it("applies theme mode correctly to documentElement", () => {
    const classList = {
      add: vi.fn(),
      remove: vi.fn(),
    };
    const mockDocElement = { classList };
    vi.stubGlobal("document", { documentElement: mockDocElement });

    applyThemeMode("dark");
    expect(classList.add).toHaveBeenCalledWith("dark");

    applyThemeMode("light");
    expect(classList.remove).toHaveBeenCalledWith("dark");
  });

  it("ensures all THEME_OPTIONS have corresponding CSS selectors in theme.css", () => {
    const cssPath = resolve(__dirname, "../styles/theme.css");
    const cssContent = readFileSync(cssPath, "utf-8");

    for (const option of THEME_OPTIONS) {
      expect(cssContent).toContain(`[data-theme="${option.id}"]`);
      expect(cssContent).toContain(`:host([data-theme="${option.id}"])`);
    }
  });
});

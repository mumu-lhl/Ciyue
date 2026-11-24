import { describe, it, expect, beforeEach } from "vitest";
import { fakeBrowser } from "wxt/testing/fake-browser";
import { getSettings, saveSettings, DEFAULT_SETTINGS } from "./settings";

describe("settings utility", () => {
  beforeEach(() => {
    fakeBrowser.reset();
  });

  it("returns default settings when storage is empty", async () => {
    const settings = await getSettings();
    expect(settings).toEqual(DEFAULT_SETTINGS);
    expect(settings.themeColor).toBe("blue");
    expect(settings.themeMode).toBe("auto");
    expect(settings.locale).toBe("auto");
  });

  it("saves and retrieves updated settings including themeColor and themeMode", async () => {
    await saveSettings({
      serverUrl: "http://localhost:12345/",
      themeColor: "emerald",
      themeMode: "dark",
      locale: "en",
      enableDoubleClick: true,
      requireModifierKey: "alt",
    });

    const settings = await getSettings();
    expect(settings.serverUrl).toBe("http://localhost:12345");
    expect(settings.themeColor).toBe("emerald");
    expect(settings.themeMode).toBe("dark");
    expect(settings.locale).toBe("en");
    expect(settings.enableDoubleClick).toBe(true);
    expect(settings.requireModifierKey).toBe("alt");
    expect(settings.enableSelection).toBe(true);
  });
});

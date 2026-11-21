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
  });

  it("saves and retrieves updated settings including themeColor", async () => {
    await saveSettings({
      serverUrl: "http://localhost:12345/",
      themeColor: "emerald",
      enableDoubleClick: true,
      requireModifierKey: "alt",
    });

    const settings = await getSettings();
    expect(settings.serverUrl).toBe("http://localhost:12345");
    expect(settings.themeColor).toBe("emerald");
    expect(settings.enableDoubleClick).toBe(true);
    expect(settings.requireModifierKey).toBe("alt");
    expect(settings.enableSelection).toBe(true);
  });
});

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
  });

  it("saves and retrieves updated settings", async () => {
    await saveSettings({
      serverUrl: "http://localhost:12345/",
      enableDoubleClick: true,
      requireModifierKey: "alt",
    });

    const settings = await getSettings();
    expect(settings.serverUrl).toBe("http://localhost:12345");
    expect(settings.enableDoubleClick).toBe(true);
    expect(settings.requireModifierKey).toBe("alt");
    expect(settings.enableSelection).toBe(true);
  });
});

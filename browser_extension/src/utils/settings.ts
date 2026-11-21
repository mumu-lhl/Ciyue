import type { ExtensionSettings } from "../api/types";

export const DEFAULT_SETTINGS: ExtensionSettings = {
  serverUrl: "http://127.0.0.1:47117",
  themeColor: "blue",
  enableSelection: true,
  enableDoubleClick: false,
  requireModifierKey: "none",
  excludeEditable: true,
  blacklistUrls: [],
};

export async function getSettings(): Promise<ExtensionSettings> {
  return new Promise((resolve) => {
    chrome.storage.sync.get(DEFAULT_SETTINGS as unknown as { [key: string]: any }, (items) => {
      const merged = { ...DEFAULT_SETTINGS, ...items };
      if (merged.serverUrl) {
        merged.serverUrl = merged.serverUrl.replace(/\/+$/, "");
      }
      resolve(merged as ExtensionSettings);
    });
  });
}

export async function saveSettings(settings: Partial<ExtensionSettings>): Promise<void> {
  return new Promise((resolve) => {
    if (settings.serverUrl) {
      settings.serverUrl = settings.serverUrl.replace(/\/+$/, "");
    }
    chrome.storage.sync.set(settings, () => {
      resolve();
    });
  });
}

export function onSettingsChanged(callback: (settings: ExtensionSettings) => void): () => void {
  const listener = () => {
    getSettings().then(callback);
  };
  chrome.storage.onChanged.addListener(listener);
  return () => {
    chrome.storage.onChanged.removeListener(listener);
  };
}

import type { Translations } from "../types";

export const en: Translations = {
  common: {
    appName: "Ciyue",
    appDesc: "Web Dictionary & Learning Center",
    search: "Search",
    searchPlaceholder: "Type a word and press Enter...",
    clear: "Clear",
    close: "Close",
    copy: "Copy",
    copied: "Copied",
    retry: "Retry",
    loading: "Loading...",
    save: "Save Settings",
    saved: "Settings saved successfully!",
    test: "Test Connection",
    testing: "Testing connection...",
    success: "Success",
    error: "Error",
    online: "Connected to Ciyue desktop",
    offline: "Disconnected from desktop service",
  },
  theme: {
    appearanceTitle: "Appearance & Theme",
    modeTitle: "Theme Mode",
    modeDesc:
      "Choose interface appearance: follow system preference or stick to light/dark",
    modeAuto: "System",
    modeLight: "Light",
    modeDark: "Dark",
    colorTitle: "Primary Color",
    colorDesc: "Choose accent color for popups, headers, and action buttons",
    blue: "Classic Blue",
    violet: "Aurora Violet",
    teal: "Alpine Teal",
    emerald: "Emerald Green",
    rose: "Rose Red",
    amber: "Amber Orange",
  },
  language: {
    title: "Language",
    desc: "Choose display language: follow browser preference or lock to a specific language",
    auto: "System",
    zh: "简体中文",
    en: "English",
  },
  header: {
    switchGroup: "Switch Dictionary Group",
    aiTranslate: "AI Translate",
    themeColor: "Theme Color",
    toggleThemeMode: "Toggle Theme Mode (Current: {mode})",
    toggleLang: "Switch Language (Current: {lang})",
    settings: "Settings",
  },
  lookup: {
    searchingWord: "Searching “{word}”...",
    notFound: "No definitions found for “{word}” in current group",
    dictCount: "Found {count} dictionary results",
    expandAll: "Expand All",
    collapseAll: "Collapse All",
    localDicts: "Local Dictionaries ({count})",
    aiExplainTab: "AI Analysis",
    aiTranslateTab: "AI Translate",
    copyLinkSuccess: "Dictionary anchor link copied",
    offlineTitle: "Unable to connect to Ciyue desktop Web service",
    offlineDesc:
      "Please ensure Ciyue desktop is running, and that the Web & API service is enabled under Settings -> Web & API Service.",
    enterWordPrompt: "Type a word and press Enter or click Search",
    searchingPrompt: "Searching dictionaries...",
  },
  wordHeader: {
    addToNotebook: "Add to Word Book",
    removeFromNotebook: "Remove from Word Book",
    savedToNotebook: "Saved to Word Book",
    aiDeepExplain: "AI Deep Analysis",
  },
  aiExplain: {
    title: "AI Deep Analysis - {word}",
    generating:
      "AI is analyzing nuances, deep definitions, and sample sentences...",
    failed: "Generation failed: ",
    promptHint:
      "To use AI features, ensure that AI model and API Key are configured in Ciyue desktop.",
  },
  aiTranslate: {
    title: "AI Smart Translation",
    inputPlaceholder: "Enter text to translate...",
    translating: "AI is translating...",
    translateBtn: "Translate",
    targetLang: "Target Language",
    failed: "Translation failed: ",
  },
  extensionOptions: {
    extSettingsTitle: "Ciyue Assistant · Extension Settings",
    extSettingsDesc:
      "Configure connection, appearance, and selection lookup behavior for the browser extension",
    serverConnection: "Desktop Service Connection",
    serverUrl: "Server URL",
    serverUrlDesc:
      "The full URL where Ciyue desktop Web & API service is listening",
    testConnSuccess:
      "Connected! Reached desktop service, current group loaded with {count} dictionaries.",
    testConnFailed:
      "Connection failed: {error}. Please ensure Ciyue desktop is running with service enabled.",
    selectionBehavior: "Web Selection Behavior",
    enableSelection: "Enable Selection Lookup",
    enableSelectionDesc:
      "Display floating lookup trigger after selecting text on web pages",
    enableDoubleClick: "Enable Double-Click Lookup",
    enableDoubleClickDesc:
      "Directly open lookup card when double-clicking words (skips trigger icon)",
    modifierKey: "Modifier Key Requirement",
    modifierKeyDesc:
      "Only trigger when selecting text while holding the specified modifier key",
    modNone: "None (Default)",
    modAlt: "Hold Alt / Option",
    modCtrl: "Hold Ctrl / Command",
    modShift: "Hold Shift",
    excludeEditable: "Exclude Input & Editable Areas",
    excludeEditableDesc:
      "Do not show lookup trigger inside text inputs or contenteditable editors",
    blacklist: "Domain Blacklist",
    blacklistDesc:
      "Disable selection lookup on these domains (one per line, e.g. github.com)",
    blacklistPlaceholder: "e.g.:\ngithub.com\nmail.google.com",
  },
};

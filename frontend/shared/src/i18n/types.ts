export type SupportedLocale = "zh" | "en";
export type LocalePreference = "auto" | "zh" | "en";

export interface Translations {
  common: {
    appName: string;
    appDesc: string;
    search: string;
    searchPlaceholder: string;
    clear: string;
    close: string;
    copy: string;
    copied: string;
    retry: string;
    loading: string;
    save: string;
    saved: string;
    test: string;
    testing: string;
    success: string;
    error: string;
    online: string;
    offline: string;
  };
  theme: {
    appearanceTitle: string;
    modeTitle: string;
    modeDesc: string;
    modeAuto: string;
    modeLight: string;
    modeDark: string;
    colorTitle: string;
    colorDesc: string;
    blue: string;
    violet: string;
    teal: string;
    emerald: string;
    rose: string;
    amber: string;
  };
  language: {
    title: string;
    desc: string;
    auto: string;
    zh: string;
    en: string;
  };
  header: {
    switchGroup: string;
    aiTranslate: string;
    themeColor: string;
    toggleThemeMode: string;
    toggleLang: string;
    settings: string;
  };
  lookup: {
    searchingWord: string;
    notFound: string;
    dictCount: string;
    expandAll: string;
    collapseAll: string;
    localDicts: string;
    aiExplainTab: string;
    aiTranslateTab: string;
    copyLinkSuccess: string;
    offlineTitle: string;
    offlineDesc: string;
    enterWordPrompt: string;
    searchingPrompt: string;
  };
  wordHeader: {
    addToNotebook: string;
    removeFromNotebook: string;
    savedToNotebook: string;
    aiDeepExplain: string;
  };
  aiExplain: {
    title: string;
    generating: string;
    failed: string;
    promptHint: string;
  };
  aiTranslate: {
    title: string;
    inputPlaceholder: string;
    translating: string;
    translateBtn: string;
    targetLang: string;
    failed: string;
  };
  extensionOptions: {
    extSettingsTitle: string;
    extSettingsDesc: string;
    serverConnection: string;
    serverUrl: string;
    serverUrlDesc: string;
    testConnSuccess: string;
    testConnFailed: string;
    selectionBehavior: string;
    enableSelection: string;
    enableSelectionDesc: string;
    enableDoubleClick: string;
    enableDoubleClickDesc: string;
    modifierKey: string;
    modifierKeyDesc: string;
    modNone: string;
    modAlt: string;
    modCtrl: string;
    modShift: string;
    excludeEditable: string;
    excludeEditableDesc: string;
    blacklist: string;
    blacklistDesc: string;
    blacklistPlaceholder: string;
  };
}

type NestedKeyOf<ObjectType extends object> = {
  [Key in keyof ObjectType & (string | number)]: ObjectType[Key] extends object
    ? `${Key}.${NestedKeyOf<ObjectType[Key]>}`
    : `${Key}`;
}[keyof ObjectType & (string | number)];

export type TranslationKey = NestedKeyOf<Translations>;

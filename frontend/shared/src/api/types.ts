export interface DictionaryResult {
  dictId: number | string;
  dictTitle: string;
  dictType?: string;
  headword: string;
  content: string;
  resourceBase: string;
}

export interface LookupResponse {
  word: string;
  currentGroupId?: number | string;
  results: DictionaryResult[];
  stared?: boolean;
}

export interface SuggestResponse {
  query: string;
  dictionarySuggestions: string[];
  spellingSuggestions: string[];
}

export interface GroupItem {
  id: number | string;
  name: string;
  isCurrent: boolean;
  dictCount?: number;
}

export interface ServerStatus {
  status: string;
  app: string;
  port: number;
  allowLan: boolean;
  currentGroupId: number | string;
  dictionariesCount: number;
  aiConfigured?: boolean;
}

export type ModifierKey = "none" | "alt" | "ctrl" | "shift";
export type ThemeColor = "blue" | "violet" | "teal" | "emerald" | "rose" | "amber";
export type ThemeMode = "auto" | "light" | "dark";

export interface ExtensionSettings {
  serverUrl: string;
  themeColor: ThemeColor;
  themeMode: ThemeMode;
  enableSelection: boolean;
  enableDoubleClick: boolean;
  requireModifierKey: ModifierKey;
  excludeEditable: boolean;
  blacklistUrls: string[];
}

export interface ProxyFetchRequest {
  url: string;
  method?: string;
  headers?: Record<string, string>;
  body?: any;
}

export interface ProxyFetchResponse<T = any> {
  ok: boolean;
  status: number;
  data?: T;
  error?: string;
}

export interface StreamChunkMessage {
  chunk?: string;
  error?: string;
  done?: boolean;
}

export interface DictionaryResult {
  dictId: string;
  dictTitle: string;
  headword: string;
  content: string;
  resourceBase: string;
}

export interface LookupResponse {
  word: string;
  results: DictionaryResult[];
  stared?: boolean;
}

export interface SuggestResponse {
  query: string;
  dictionarySuggestions: string[];
  spellingSuggestions: string[];
}

export interface GroupItem {
  id: string;
  name: string;
  isCurrent: boolean;
  dictCount: number;
}

export interface ServerStatus {
  status: string;
  app: string;
  port: number;
  allowLan: boolean;
  currentGroupId: string;
  dictionariesCount: number;
}

export type ModifierKey = "none" | "alt" | "ctrl" | "shift";

export interface ExtensionSettings {
  serverUrl: string;
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

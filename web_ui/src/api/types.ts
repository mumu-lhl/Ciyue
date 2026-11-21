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

export type ThemeColor = "blue" | "violet" | "teal" | "emerald" | "rose" | "amber";
export type ThemeMode = "auto" | "light" | "dark";

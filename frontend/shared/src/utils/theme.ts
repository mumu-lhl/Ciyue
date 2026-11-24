import type { ThemeColor, ThemeMode } from "../api/types";
import { t } from "../i18n";
import type { SupportedLocale, TranslationKey } from "../i18n/types";

export interface ThemeOption {
  id: ThemeColor;
  name: string;
  primaryHex: string;
}

export const THEME_OPTIONS: ThemeOption[] = [
  { id: "blue", name: "经典蓝", primaryHex: "#2563eb" },
  { id: "violet", name: "极光紫", primaryHex: "#7c3aed" },
  { id: "teal", name: "苍岭青", primaryHex: "#0d9488" },
  { id: "emerald", name: "翡翠绿", primaryHex: "#059669" },
  { id: "rose", name: "玫瑰红", primaryHex: "#e11d48" },
  { id: "amber", name: "琥珀橙", primaryHex: "#d97706" },
];

export function getThemeName(color: ThemeColor, locale: SupportedLocale = "zh"): string {
  const map: Record<ThemeColor, TranslationKey> = {
    blue: "theme.blue",
    violet: "theme.violet",
    teal: "theme.teal",
    emerald: "theme.emerald",
    rose: "theme.rose",
    amber: "theme.amber",
  };
  return t(map[color] ?? "theme.blue", undefined, locale);
}

export function isValidThemeColor(color: string): color is ThemeColor {
  return THEME_OPTIONS.some((t) => t.id === color);
}

export function getThemeOption(color: ThemeColor): ThemeOption {
  return THEME_OPTIONS.find((t) => t.id === color) ?? THEME_OPTIONS[0]!;
}

export function getStoredThemeMode(): ThemeMode {
  try {
    if (typeof localStorage === "undefined") return "auto";
    const stored = localStorage.getItem("ciyue_theme_mode");
    if (stored === "light" || stored === "dark" || stored === "auto") return stored;
  } catch {}
  return "auto";
}

export function setStoredThemeMode(mode: ThemeMode): void {
  try {
    if (typeof localStorage !== "undefined") {
      localStorage.setItem("ciyue_theme_mode", mode);
    }
  } catch {}
}

export function getStoredThemeColor(): ThemeColor {
  try {
    if (typeof localStorage === "undefined") return "blue";
    const stored = localStorage.getItem("ciyue_theme_color");
    if (THEME_OPTIONS.some((t) => t.id === stored)) return stored as ThemeColor;
  } catch {}
  return "blue";
}

export function setStoredThemeColor(color: ThemeColor): void {
  try {
    if (typeof localStorage !== "undefined") {
      localStorage.setItem("ciyue_theme_color", color);
    }
  } catch {}
}

export function applyThemeColor(color: ThemeColor, rootElement?: HTMLElement): void {
  const target = rootElement ?? (typeof document !== "undefined" ? document.documentElement : null);
  if (!target) return;
  target.setAttribute("data-theme", color);
}

export function applyThemeMode(mode: ThemeMode, rootElement?: HTMLElement): void {
  const target = rootElement ?? (typeof document !== "undefined" ? document.documentElement : null);
  if (!target) return;
  if (mode === "dark") {
    target.classList.add("dark");
  } else if (mode === "light") {
    target.classList.remove("dark");
  } else if (typeof window !== "undefined" && window.matchMedia) {
    const isDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    if (isDark) {
      target.classList.add("dark");
    } else {
      target.classList.remove("dark");
    }
  }
}

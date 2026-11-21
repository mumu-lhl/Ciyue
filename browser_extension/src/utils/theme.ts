import type { ThemeColor } from "../api/types";

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

export function isValidThemeColor(color: string): color is ThemeColor {
  return THEME_OPTIONS.some((t) => t.id === color);
}

export function getThemeOption(color: ThemeColor): ThemeOption {
  return THEME_OPTIONS.find((t) => t.id === color) ?? THEME_OPTIONS[0]!;
}

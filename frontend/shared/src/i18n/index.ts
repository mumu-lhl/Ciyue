import { zh } from "./locales/zh";
import { en } from "./locales/en";
import type {
  LocalePreference,
  SupportedLocale,
  TranslationKey,
  Translations,
} from "./types";

export * from "./types";
export { zh, en };

export const LOCALES: Record<SupportedLocale, Translations> = {
  zh,
  en,
};

export function resolveLocale(pref: LocalePreference): SupportedLocale {
  if (pref === "zh" || pref === "en") return pref;
  if (typeof navigator !== "undefined" && navigator.language) {
    const lang = navigator.language.toLowerCase();
    if (lang.startsWith("zh")) return "zh";
  }
  return "en";
}

export function getStoredLocale(): LocalePreference {
  try {
    if (typeof localStorage === "undefined") return "auto";
    const val = localStorage.getItem("ciyue_locale");
    if (val === "zh" || val === "en" || val === "auto") return val;
  } catch {}
  return "auto";
}

export function setStoredLocale(pref: LocalePreference): void {
  try {
    if (typeof localStorage !== "undefined") {
      localStorage.setItem("ciyue_locale", pref);
    }
  } catch {}
}

export function t(
  key: TranslationKey,
  params?: Record<string, string | number>,
  locale: SupportedLocale = "zh",
): string {
  const dict = LOCALES[locale] ?? LOCALES.zh;
  const parts = key.split(".");
  let cur: any = dict;
  for (const part of parts) {
    cur = cur?.[part];
    if (cur === undefined) break;
  }

  // Fallback to zh if not found in target locale
  if (typeof cur !== "string" && locale !== "zh") {
    let fallback: any = LOCALES.zh;
    for (const part of parts) {
      fallback = fallback?.[part];
      if (fallback === undefined) break;
    }
    if (typeof fallback === "string") cur = fallback;
  }

  if (typeof cur !== "string") {
    return key;
  }

  if (!params) return cur;

  return cur.replace(/\{(\w+)\}/g, (_, k) => {
    return params[k] !== undefined ? String(params[k]) : `{${k}}`;
  });
}

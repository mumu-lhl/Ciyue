import {
  getStoredLocale,
  resolveLocale,
  setStoredLocale,
  t as rawT,
  type LocalePreference,
  type SupportedLocale,
  type TranslationKey,
} from "@ciyue/shared";

class WebUiI18nManager {
  preference = $state<LocalePreference>("auto");
  currentLocale = $state<SupportedLocale>("zh");

  constructor() {
    this.preference = getStoredLocale();
    this.currentLocale = resolveLocale(this.preference);
  }

  setLocalePreference(pref: LocalePreference) {
    this.preference = pref;
    setStoredLocale(pref);
    this.currentLocale = resolveLocale(pref);
  }

  t(key: TranslationKey, params?: Record<string, string | number>): string {
    return rawT(key, params, this.currentLocale);
  }
}

export const i18n = new WebUiI18nManager();
export const t = (key: TranslationKey, params?: Record<string, string | number>): string =>
  i18n.t(key, params);

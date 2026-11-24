import {
  resolveLocale,
  t as rawT,
  type LocalePreference,
  type SupportedLocale,
  type TranslationKey,
} from "@ciyue/shared";
import { getSettings, onSettingsChanged, saveSettings } from "./settings";

class ExtensionI18nManager {
  preference = $state<LocalePreference>("auto");
  currentLocale = $state<SupportedLocale>("zh");

  constructor() {
    getSettings().then((s) => {
      this.preference = s.locale ?? "auto";
      this.currentLocale = resolveLocale(this.preference);
    });

    onSettingsChanged((newSettings) => {
      this.preference = newSettings.locale ?? "auto";
      this.currentLocale = resolveLocale(this.preference);
    });
  }

  async setLocalePreference(pref: LocalePreference) {
    this.preference = pref;
    this.currentLocale = resolveLocale(pref);
    await saveSettings({ locale: pref });
  }

  t(key: TranslationKey, params?: Record<string, string | number>): string {
    return rawT(key, params, this.currentLocale);
  }
}

export const i18n = new ExtensionI18nManager();
export const t = (key: TranslationKey, params?: Record<string, string | number>): string =>
  i18n.t(key, params);

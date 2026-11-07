import "package:ciyue/src/generated/i18n/app_localizations.dart";

/// Names for languages offered as translation or pronunciation targets.
/// The app-language selector shows each language's own name, but functional
/// pickers follow the current UI language instead.
String localizedLanguageName(String code, AppLocalizations l10n) {
  switch (code) {
    case "auto":
      return l10n.autoDetect;
    case "en":
      return l10n.languageNameEn;
    case "zh":
      return l10n.languageNameZh;
    case "zh_HK":
      return l10n.languageNameZhHk;
    case "zh_TW":
      return l10n.languageNameZhTw;
    case "ja":
      return l10n.languageNameJa;
    case "ko":
      return l10n.languageNameKo;
    case "fr":
      return l10n.languageNameFr;
    case "de":
      return l10n.languageNameDe;
    case "es":
      return l10n.languageNameEs;
    case "ru":
      return l10n.languageNameRu;
    case "hi":
      return l10n.languageNameHi;
    case "bn":
      return l10n.languageNameBn;
    case "ca":
      return l10n.languageNameCa;
    case "nb":
      return l10n.languageNameNb;
    case "sc":
      return l10n.languageNameSc;
    case "ta":
      return l10n.languageNameTa;
    case "fa":
      return l10n.languageNameFa;
    case "bg":
      return l10n.languageNameBg;
    case "vi":
      return l10n.languageNameVi;
    case "it":
      return l10n.languageNameIt;
    case "pt":
      return l10n.languageNamePt;
    case "nl":
      return l10n.languageNameNl;
    case "sv":
      return l10n.languageNameSv;
    case "da":
      return l10n.languageNameDa;
    case "no":
      return l10n.languageNameNo;
    case "fi":
      return l10n.languageNameFi;
    case "pl":
      return l10n.languageNamePl;
    case "cs":
      return l10n.languageNameCs;
    case "hu":
      return l10n.languageNameHu;
    case "tr":
      return l10n.languageNameTr;
    case "ar":
      return l10n.languageNameAr;
    case "he":
      return l10n.languageNameHe;
    case "th":
      return l10n.languageNameTh;
    case "id":
      return l10n.languageNameId;
    case "uk":
      return l10n.languageNameUk;
    case "el":
      return l10n.languageNameEl;
    default:
      return code;
  }
}

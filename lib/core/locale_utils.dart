import "dart:ui" show Locale;

/// Parses a language setting such as `zh`, `zh_HK`, or `zh_Seal` into the
/// [Locale] handed to `MaterialApp`.
///
/// A four-letter subtag is a script code. gen-l10n names the generated
/// class after `Locale.toString()`, so the script must be title-cased
/// (`Seal`, not `seal`) for `lookupAppLocalizations` to resolve it.
Locale? localeFromLanguageCode(String? code) {
  if (code == null || code.isEmpty || code == "system") {
    return null;
  }
  final parts = code.split("_");
  if (parts.length == 1) {
    return Locale(parts[0]);
  }
  final subtag = parts[1];
  if (subtag.length == 4) {
    return Locale.fromSubtags(
      languageCode: parts[0],
      scriptCode: subtag[0].toUpperCase() + subtag.substring(1).toLowerCase(),
    );
  }
  return Locale.fromSubtags(languageCode: parts[0], countryCode: subtag);
}

/// Language code for features that talk to AI or translation providers.
///
/// `zh_Seal` is a decorative Chinese script, not a language providers know,
/// so those features must use the underlying `zh` code.
String functionalLanguageCode(String code) => code == "zh_Seal" ? "zh" : code;

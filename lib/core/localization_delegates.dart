import "package:flutter/cupertino.dart";
import "package:material_ui/material_ui.dart";

/// Flutter's own localizations do not cover every language the app ships.
/// A language that is missing from them leaves the widgets that need them
/// without a translation, and those widgets fail to build, which shows up
/// as an empty box where they should be.
///
/// The default English localizations are used for those languages, the same
/// way an untranslated string falls back to English.
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate([
    this.languageCodes = const {"sc", "got"},
  ]);

  /// The languages that Flutter does not translate itself.
  final Set<String> languageCodes;

  @override
  bool isSupported(Locale locale) =>
      languageCodes.contains(locale.languageCode);

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return const DefaultMaterialLocalizations();
  }

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

/// The same fallback for the widget localizations, which cover fewer
/// languages than the app itself does.
class FallbackWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const FallbackWidgetsLocalizationsDelegate([
    this.languageCodes = const {"sc", "got"},
  ]);

  final Set<String> languageCodes;

  @override
  bool isSupported(Locale locale) =>
      languageCodes.contains(locale.languageCode);

  @override
  Future<WidgetsLocalizations> load(Locale locale) async {
    return const DefaultWidgetsLocalizations();
  }

  @override
  bool shouldReload(FallbackWidgetsLocalizationsDelegate old) => false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate([
    this.languageCodes = const {"sc", "got"},
  ]);

  final Set<String> languageCodes;

  @override
  bool isSupported(Locale locale) =>
      languageCodes.contains(locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    return const DefaultCupertinoLocalizations();
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}

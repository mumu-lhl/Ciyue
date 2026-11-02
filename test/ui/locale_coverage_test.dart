import "package:ciyue/core/localization_delegates.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  test("every locale the app ships has Material localizations", () {
    // Flutter translates most of the languages, but not all of them. A
    // locale it does not know leaves the widgets that depend on those
    // localizations without them, and they fail to build.
    const fallback = FallbackMaterialLocalizationsDelegate();

    for (final locale in AppLocalizations.supportedLocales) {
      final translated = GlobalMaterialLocalizations.delegate.isSupported(
        locale,
      );
      expect(
        translated || fallback.isSupported(locale),
        isTrue,
        reason:
            "The locale ${locale.toLanguageTag()} has no Material "
            "localizations: Flutter does not translate it and it is missing "
            "from the fallback list of FallbackMaterialLocalizationsDelegate.",
      );
    }
  });
}

import "package:ciyue/core/localization_delegates.dart";
import "package:ciyue/core/locale_utils.dart";
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

  test("zh_Seal keeps its script subtag", () {
    expect(
      localeFromLanguageCode("zh_Seal"),
      Locale.fromSubtags(languageCode: "zh", scriptCode: "Seal"),
    );
    // The decorative script must not leak into provider-facing features.
    expect(functionalLanguageCode("zh_Seal"), "zh");
    expect(functionalLanguageCode("zh_HK"), "zh_HK");
  });

  testWidgets("zh_Seal builds with the real localization delegates", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: localeFromLanguageCode("zh_Seal"),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
          const FallbackMaterialLocalizationsDelegate(),
          const FallbackWidgetsLocalizationsDelegate(),
          const FallbackCupertinoLocalizationsDelegate(),
        ],
        home: Builder(
          builder: (context) => Text(AppLocalizations.of(context)!.home),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Text), findsOneWidget);
  });
}

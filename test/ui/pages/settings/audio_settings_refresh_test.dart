import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/audio.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/app_dropdown.dart";
import "package:ciyue/ui/pages/settings/audio.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";
import "package:simple_secure_storage/simple_secure_storage.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    // OnlinePronunciationSettings reads the stored Forvo key in initState
    // through the secure-storage method channel, which has no handler in
    // tests: answer "no stored key" instead of throwing. The channel
    // implementation needs initialize() first (it sets the key prefix
    // used when building every call's arguments).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel("fr.skyost.simple_secure_storage"),
          (MethodCall call) async => null,
        );
    await SimpleSecureStorage.initialize();
  });

  setUp(() {
    settings.pronunciationMode = PronunciationMode.packFirst;
    settings.wiktionaryPronunciationEnabled = false;
    settings.forvoPronunciationEnabled = false;
    settings.wiktionaryPronunciationLanguage = "";
    settings.forvoPronunciationLanguage = "";
  });

  Future<void> pumpSection(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("en"),
          home: Scaffold(body: ListView(children: [child])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("toggling the Wiktionary switch updates the switch", (
    tester,
  ) async {
    await pumpSection(tester, const OnlinePronunciationSettings());

    final tile = find.widgetWithText(SwitchListTile, "Wiktionary");
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(settings.wiktionaryPronunciationEnabled, isTrue);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
  });

  testWidgets("selecting a pronunciation mode updates the dropdown field", (
    tester,
  ) async {
    await pumpSection(tester, const PronunciationModeSelector());

    expect(find.text("Packs first, TTS as fallback"), findsOneWidget);

    await tester.tap(find.byType(AppDropdown<PronunciationMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("TTS only").last);
    await tester.pumpAndSettle();

    expect(settings.pronunciationMode, PronunciationMode.ttsOnly);
    expect(find.text("TTS only"), findsOneWidget);
    expect(find.text("Packs first, TTS as fallback"), findsNothing);
  });
}

import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/linux_tts.dart";
import "package:ciyue/services/linux_tts_driver.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/audio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

/// Fake Linux TTS driver: no processes or audio.
class _FakeLinuxTtsDriver implements LinuxTtsDriver {
  LinuxTtsAvailability availability = const LinuxTtsAvailability(
    ssip: true,
    espeak: true,
  );
  List<LinuxVoice> voiceList = [];
  int detectCalls = 0;
  String? lastVoicesLanguage;

  @override
  Future<LinuxTtsAvailability> detect({bool refresh = false}) async {
    detectCalls++;
    return availability;
  }

  @override
  Future<List<LinuxVoice>> voices({String? language}) async {
    lastVoicesLanguage = language;
    return voiceList;
  }

  @override
  Future<SsipSpeakResult> speak(
    String text, {
    String? language,
    double? rate,
    double? pitch,
    String? voice,
  }) async => SsipSpeakResult.success(null);

  @override
  Future<void> stop() async {}

  @override
  Future<Uint8List?> synthesizeWav(
    String text, {
    String? voice,
    double? rate,
    double? pitch,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
  });

  late _FakeLinuxTtsDriver fake;

  setUp(() {
    fake = _FakeLinuxTtsDriver();
    linuxTtsDriverOverride = fake;
    settings.ttsLanguage = "en";
    settings.linuxTtsVoice = null;
  });

  tearDown(() {
    linuxTtsDriverOverride = null;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale("en"),
        home: const Scaffold(body: LinuxTtsSettings()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("shows backend status and voice picker", (tester) async {
    fake.voiceList = [
      const LinuxVoice(
        id: "English_(America)",
        language: "en-us",
        variant: "--/M",
        displayName: "English_(America) (en-us)",
      ),
      const LinuxVoice(
        id: "English_(Great_Britain)",
        language: "en-gb",
        variant: "--/M",
        displayName: "English_(Great_Britain) (en-gb)",
      ),
    ];

    await pumpSettings(tester);

    expect(fake.detectCalls, 1);
    expect(fake.lastVoicesLanguage, "en");
    expect(
      find.text("Available backends: Speech Dispatcher, espeak-ng"),
      findsOneWidget,
    );
    expect(find.text("Default voice"), findsOneWidget);

    // Picking a voice persists the voice id.
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("English_(America) (en-us)").last);
    await tester.pumpAndSettle();
    expect(settings.linuxTtsVoice, "English_(America)");
    expect(prefs.getString("linuxTtsVoice"), "English_(America)");
  });

  testWidgets("shows the no-backend hint when nothing is detected", (
    tester,
  ) async {
    fake.availability = const LinuxTtsAvailability(ssip: false, espeak: false);

    await pumpSettings(tester);

    expect(find.textContaining("No TTS backend was found"), findsOneWidget);
    expect(find.text("Default voice"), findsOneWidget);
  });

  testWidgets("refresh re-probes detection", (tester) async {
    await pumpSettings(tester);
    expect(fake.detectCalls, 1);

    await tester.tap(find.text("Refresh voices"));
    await tester.pumpAndSettle();

    expect(fake.detectCalls, 2);
  });
}

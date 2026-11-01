import "package:audioplayers/audioplayers.dart";
import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/linux_tts.dart";
import "package:ciyue/services/linux_tts_driver.dart";
import "package:ciyue/services/tts.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

/// Fake Linux TTS driver: no processes, network, or audio.
class _FakeLinuxTtsDriver implements LinuxTtsDriver {
  SsipSpeakResult speakResult = SsipSpeakResult.success(null);
  Uint8List? wavResult;
  Object? speakError;

  int speakCalls = 0;
  int wavCalls = 0;
  int stopCalls = 0;
  String? lastText;
  String? lastLanguage;
  double? lastRate;
  double? lastPitch;
  String? lastVoice;

  @override
  Future<LinuxTtsAvailability> detect({bool refresh = false}) async =>
      const LinuxTtsAvailability(ssip: true, espeak: true);

  @override
  Future<List<LinuxVoice>> voices({String? language}) async => [];

  @override
  Future<SsipSpeakResult> speak(
    String text, {
    String? language,
    double? rate,
    double? pitch,
    String? voice,
  }) async {
    speakCalls++;
    lastText = text;
    lastLanguage = language;
    lastRate = rate;
    lastPitch = pitch;
    lastVoice = voice;
    if (speakError != null) throw speakError!;
    return speakResult;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<Uint8List?> synthesizeWav(
    String text, {
    String? voice,
    double? rate,
    double? pitch,
  }) async {
    wavCalls++;
    return wavResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Duration previousPreparationTimeout;

  setUpAll(() async {
    // The WAV fallback plays through an AudioPlayer; mock its
    // channels (as the pronunciation chain tests do) so player
    // creation never surfaces an unhandled async error, and fail
    // the preparation wait fast.
    previousPreparationTimeout = AudioPlayer.preparationTimeout;
    AudioPlayer.preparationTimeout = const Duration(milliseconds: 100);
    final messenger = TestWidgetsFlutterBinding.instance.defaultBinaryMessenger;
    for (final name in [
      "xyz.luan/audioplayers",
      "xyz.luan/audioplayers.global",
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (MethodCall call) async => null,
      );
    }

    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
  });

  tearDownAll(() {
    AudioPlayer.preparationTimeout = previousPreparationTimeout;
  });

  late _FakeLinuxTtsDriver fake;

  setUp(() {
    fake = _FakeLinuxTtsDriver();
    linuxTtsDriverOverride = fake;
    settings.ttsLanguage = "en-US";
    settings.linuxTtsVoice = null;
    settings.ttsSpeechRate = 0.5;
    settings.ttsPitch = 1.0;
    ttsDisabledByCommandLine = false;
  });

  tearDown(() async {
    await TtsHelper.stop();
    linuxTtsDriverOverride = null;
    ttsDisabledByCommandLine = false;
  });

  test("toggleSpeak speaks stripped text via SSIP", () async {
    await TtsHelper.toggleSpeak("**Hello** _world_");

    expect(fake.speakCalls, 1);
    expect(fake.lastText, "Hello world");
    expect(fake.lastLanguage, "en-US");
    expect(fake.lastRate, 0.5);
    expect(fake.lastPitch, 1.0);
    expect(fake.lastVoice, isNull);
    expect(fake.wavCalls, 0);
    expect(TtsHelper.isSpeaking, isTrue);
  });

  test("second tap on the same text stops speech", () async {
    await TtsHelper.toggleSpeak("Hello");
    expect(TtsHelper.isSpeaking, isTrue);
    final speakCalls = fake.speakCalls;
    final stopCallsBefore = fake.stopCalls;

    await TtsHelper.toggleSpeak("Hello");

    expect(fake.speakCalls, speakCalls);
    expect(fake.stopCalls, greaterThan(stopCallsBefore));
    expect(TtsHelper.isSpeaking, isFalse);
  });

  test("speaking a different text interrupts the previous one", () async {
    await TtsHelper.toggleSpeak("one");
    await TtsHelper.toggleSpeak("two");

    expect(fake.speakCalls, 2);
    expect(fake.lastText, "two");
    expect(TtsHelper.isSpeaking, isTrue);
  });

  test("stop clears state and stops the Linux backend", () async {
    await TtsHelper.toggleSpeak("Hello");
    expect(TtsHelper.isSpeaking, isTrue);

    final stopCallsBefore = fake.stopCalls;
    await TtsHelper.stop();

    expect(fake.stopCalls, greaterThan(stopCallsBefore));
    expect(TtsHelper.isSpeaking, isFalse);
  });

  test("SSIP failure falls back to synthesized WAV", () async {
    fake.speakResult = SsipSpeakResult.failure("daemon down");
    fake.wavResult = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 1]);

    await TtsHelper.toggleSpeak("Hello");

    expect(fake.speakCalls, 1);
    expect(fake.wavCalls, 1);
  });

  test("both backends failing clears the speaking state", () async {
    fake.speakResult = SsipSpeakResult.failure("daemon down");
    fake.wavResult = null;

    await TtsHelper.toggleSpeak("Hello");

    expect(fake.speakCalls, 1);
    expect(fake.wavCalls, 1);
    expect(TtsHelper.isSpeaking, isFalse);
  });

  test("command-line TTS disable never calls Linux TTS", () async {
    ttsDisabledByCommandLine = true;

    await TtsHelper.toggleSpeak("Hello");

    expect(fake.speakCalls, 0);
    expect(fake.wavCalls, 0);
    expect(TtsHelper.isSpeaking, isFalse);
  });
}

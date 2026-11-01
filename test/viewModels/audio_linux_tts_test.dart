import "package:audioplayers/audioplayers.dart";
import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/audio.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/linux_tts.dart";
import "package:ciyue/services/linux_tts_driver.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

/// Fake Linux TTS driver: no processes, network, or audio. Records
/// every call so the chain's backend order and parameter forwarding
/// can be asserted.
class _FakeLinuxTtsDriver implements LinuxTtsDriver {
  SsipSpeakResult speakResult = SsipSpeakResult.success(null);
  Uint8List? wavResult;
  Object? speakError;
  Object? wavError;
  LinuxTtsAvailability availability = const LinuxTtsAvailability(
    ssip: true,
    espeak: true,
  );
  List<LinuxVoice> voiceList = [];

  int speakCalls = 0;
  int wavCalls = 0;
  int stopCalls = 0;
  String? lastText;
  String? lastLanguage;
  double? lastRate;
  double? lastPitch;
  String? lastVoice;
  String? lastWavVoice;
  double? lastWavRate;
  double? lastWavPitch;

  @override
  Future<LinuxTtsAvailability> detect({bool refresh = false}) async =>
      availability;

  @override
  Future<List<LinuxVoice>> voices({String? language}) async => voiceList;

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
    lastWavVoice = voice;
    lastWavRate = rate;
    lastWavPitch = pitch;
    if (wavError != null) throw wavError!;
    return wavResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Duration previousPreparationTimeout;

  setUpAll(() async {
    // Same AudioPlayer mocking as the online-pronunciation chain
    // tests: the espeak WAV fallback plays through playAudioBytes,
    // whose player creation must not surface unhandled async
    // errors, and whose preparation wait must fail fast.
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
    settings.pronunciationMode = PronunciationMode.packFirst;
    settings.wiktionaryPronunciationEnabled = false;
    settings.forvoPronunciationEnabled = false;
    settings.ttsLanguage = null;
    settings.linuxTtsVoice = null;
    settings.ttsSpeechRate = 0.5;
    settings.ttsPitch = 1.0;
    ttsDisabledByCommandLine = false;
  });

  tearDown(() {
    linuxTtsDriverOverride = null;
    ttsDisabledByCommandLine = false;
  });

  AudioModel newModel() {
    final model = AudioModel();
    addTearDown(model.dispose);
    return model;
  }

  test("SSIP hit returns .tts and forwards settings", () async {
    final model = newModel();
    settings.ttsLanguage = "en-US";
    settings.ttsSpeechRate = 0.7;
    settings.ttsPitch = 1.2;

    final result = await model.playWord("apple", mddList: []);

    expect(result, PronunciationResult.tts);
    expect(fake.speakCalls, 1);
    expect(fake.lastText, "apple");
    expect(fake.lastLanguage, "en-US");
    expect(fake.lastRate, 0.7);
    expect(fake.lastPitch, 1.2);
    expect(fake.lastVoice, isNull);
    expect(fake.wavCalls, 0);
    expect(model.isPlaying, isTrue);
    expect(model.playingWord, "apple");
  });

  test("SSIP hit in ttsOnly mode returns .tts", () async {
    final model = newModel();
    settings.pronunciationMode = PronunciationMode.ttsOnly;

    final result = await model.playWord("apple", mddList: []);

    expect(result, PronunciationResult.tts);
    expect(fake.speakCalls, 1);
  });

  test("SSIP failure falls back to espeak WAV and returns .tts", () async {
    final model = newModel();
    fake.speakResult = SsipSpeakResult.failure("daemon down");
    fake.wavResult = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 1, 2, 3]);
    settings.linuxTtsVoice = "en+f3";

    final result = await model.playWord("apple", mddList: []);

    expect(result, PronunciationResult.tts);
    expect(fake.speakCalls, 1);
    expect(fake.wavCalls, 1);
    expect(fake.lastWavVoice, "en+f3");
    expect(fake.lastWavRate, 0.5);
    expect(fake.lastWavPitch, 1.0);
  });

  test("both backends failing returns .unavailable", () async {
    final model = newModel();
    fake.speakResult = SsipSpeakResult.failure("daemon down");
    fake.wavResult = null;

    final result = await model.playWord("apple", mddList: []);

    expect(result, PronunciationResult.unavailable);
    expect(fake.speakCalls, 1);
    expect(fake.wavCalls, 1);
    expect(model.isPlaying, isFalse);
  });

  test("throwing backends return .unavailable", () async {
    final model = newModel();
    fake.speakError = StateError("speak exploded");
    fake.wavError = StateError("synthesis exploded");

    final result = await model.playWord("apple", mddList: []);

    expect(result, PronunciationResult.unavailable);
    expect(fake.speakCalls, 1);
    expect(fake.wavCalls, 1);
  });

  test("packOnly never calls Linux TTS", () async {
    final model = newModel();
    settings.pronunciationMode = PronunciationMode.packOnly;

    final result = await model.playWord("apple", mddList: []);

    expect(result, PronunciationResult.unavailable);
    expect(fake.speakCalls, 0);
    expect(fake.wavCalls, 0);
  });

  test("command-line TTS disable never calls Linux TTS", () async {
    final model = newModel();
    ttsDisabledByCommandLine = true;

    final result = await model.playWord("apple", mddList: []);

    expect(result, PronunciationResult.unavailable);
    expect(fake.speakCalls, 0);
    expect(fake.wavCalls, 0);
  });

  test("stopAudio stops Linux speech", () async {
    final model = newModel();

    final result = await model.playWord("apple", mddList: []);
    expect(result, PronunciationResult.tts);
    expect(model.isPlaying, isTrue);

    fake.stopCalls = 0;
    await model.stopAudio();

    expect(fake.stopCalls, 1);
    expect(model.isPlaying, isFalse);
    expect(model.playingWord, isNull);
  });

  test("saved Linux voice id is forwarded to speak", () async {
    final model = newModel();
    settings.linuxTtsVoice = "English_(America)";
    settings.ttsLanguage = "en";

    final result = await model.playWord("apple", mddList: []);

    expect(result, PronunciationResult.tts);
    expect(fake.lastVoice, "English_(America)");
    expect(fake.lastLanguage, "en");
  });
}

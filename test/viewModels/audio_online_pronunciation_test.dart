import "dart:io";

import "package:audioplayers/audioplayers.dart";
import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/audio.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/linux_tts.dart";
import "package:ciyue/services/linux_tts_driver.dart";
import "package:ciyue/services/online_pronunciation.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

/// A fake online source that counts how often the chain consults it.
/// The chain is exercised with `mddList: []` so no Drift DAO is read.
class _CountingSource implements OnlinePronunciationSource {
  _CountingSource(this.id);

  @override
  final String id;
  Uint8List? result;
  int calls = 0;
  String? lastWord;
  String? lastLanguage;

  @override
  Future<Uint8List?> fetchAudio(String word, String languageCode) async {
    calls++;
    lastWord = word;
    lastLanguage = languageCode;
    return result;
  }
}

/// A Linux TTS driver that never speaks, so these online-chain
/// assertions do not depend on which native backends the host
/// happens to have installed: without it, a host with espeak-ng
/// would make the fall-through tests return `.tts` via the WAV
/// fallback instead of `.unavailable`.
class _NeverSpeaksLinuxTtsDriver implements LinuxTtsDriver {
  @override
  Future<LinuxTtsAvailability> detect({bool refresh = false}) async =>
      const LinuxTtsAvailability(ssip: false, espeak: false);

  @override
  Future<List<LinuxVoice>> voices({String? language}) async => [];

  @override
  Future<SsipSpeakResult> speak(
    String text, {
    String? language,
    double? rate,
    double? pitch,
    String? voice,
  }) async => SsipSpeakResult.failure("no backend");

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

  late Duration previousPreparationTimeout;

  setUpAll(() async {
    // AudioPlayer completes its creation completer with the plugin
    // error when no platform implementation exists, and flutter_test
    // reports that as an unhandled async error even though
    // playAudioBytes catches it. Mock the plugin channels so player
    // creation succeeds and playback is a no-op in tests; the chain
    // assertions only need playWord's result and the source call
    // counts, not real audio output.
    //
    // The mocked platform never emits the "prepared" event that
    // setSourceBytes waits for, so shorten the static preparation
    // timeout: playback then fails fast inside playAudioBytes (which
    // playWord already tolerates) instead of racing the 30s test
    // timeout.
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
    // No allowList: the Settings singleton reads dozens of keys.
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
  });

  tearDownAll(() {
    AudioPlayer.preparationTimeout = previousPreparationTimeout;
  });

  late Directory tempDir;
  late _CountingSource wiktionary;
  late _CountingSource forvo;

  setUp(() async {
    linuxTtsDriverOverride = _NeverSpeaksLinuxTtsDriver();
    tempDir = await Directory.systemTemp.createTemp(
      "audio_online_pronunciation_test_",
    );
    wiktionary = _CountingSource("wiktionary");
    forvo = _CountingSource("forvo");
    settings.pronunciationMode = PronunciationMode.packFirst;
    settings.wiktionaryPronunciationEnabled = false;
    settings.forvoPronunciationEnabled = false;
    settings.wiktionaryPronunciationLanguage = "";
    settings.forvoPronunciationLanguage = "";
    settings.language = "system";
    onlinePronunciationCoordinatorOverride = OnlinePronunciationCoordinator(
      sources: [wiktionary, forvo],
      cache: OnlinePronunciationCache(tempDir),
    );
  });

  tearDown(() async {
    onlinePronunciationCoordinatorOverride = null;
    linuxTtsDriverOverride = null;
    await tempDir.delete(recursive: true);
  });

  AudioModel newModel() {
    final model = AudioModel();
    addTearDown(model.dispose);
    return model;
  }

  test("online hit returns .online and does not fall through", () async {
    final model = newModel();
    settings.wiktionaryPronunciationEnabled = true;
    wiktionary.result = Uint8List.fromList([1, 2, 3]);

    final result = await model.playWord("apple", mddList: []);

    expect(result, PronunciationResult.online);
    expect(wiktionary.calls, 1);
    expect(wiktionary.lastWord, "apple");
    expect(forvo.calls, 0);
  });

  test(
    "online miss with no sources enabled falls through to unavailable",
    () async {
      final model = newModel();

      final result = await model.playWord("apple", mddList: []);

      // The fake Linux TTS driver never speaks, so the chain
      // falls through to unavailable.
      expect(result, PronunciationResult.unavailable);
      expect(wiktionary.calls, 0);
      expect(forvo.calls, 0);
    },
  );

  test(
    "online miss with sources enabled falls through after trying them",
    () async {
      final model = newModel();
      settings.wiktionaryPronunciationEnabled = true;
      settings.forvoPronunciationEnabled = true;

      final result = await model.playWord("apple", mddList: []);

      expect(result, PronunciationResult.unavailable);
      expect(wiktionary.calls, 1);
      expect(forvo.calls, 1);
    },
  );

  test("forvo is tried when wiktionary misses, in chain order", () async {
    final model = newModel();
    settings.wiktionaryPronunciationEnabled = true;
    settings.forvoPronunciationEnabled = true;
    forvo.result = Uint8List.fromList([7]);

    final result = await model.playWord("apple", mddList: []);

    expect(result, PronunciationResult.online);
    expect(wiktionary.calls, 1);
    expect(forvo.calls, 1);
  });

  test("packOnly never calls online sources", () async {
    final model = newModel();
    settings.pronunciationMode = PronunciationMode.packOnly;
    settings.wiktionaryPronunciationEnabled = true;
    settings.forvoPronunciationEnabled = true;
    wiktionary.result = Uint8List.fromList([1]);
    forvo.result = Uint8List.fromList([2]);

    final result = await model.playWord("apple", mddList: []);

    expect(result, PronunciationResult.unavailable);
    expect(wiktionary.calls, 0);
    expect(forvo.calls, 0);
  });

  test("ttsOnly never calls online sources", () async {
    final model = newModel();
    settings.pronunciationMode = PronunciationMode.ttsOnly;
    settings.wiktionaryPronunciationEnabled = true;
    settings.forvoPronunciationEnabled = true;
    wiktionary.result = Uint8List.fromList([1]);
    forvo.result = Uint8List.fromList([2]);

    final result = await model.playWord("apple", mddList: []);

    // The fake Linux TTS driver never speaks; the point here is
    // that the online sources were never consulted.
    expect(result, PronunciationResult.unavailable);
    expect(wiktionary.calls, 0);
    expect(forvo.calls, 0);
  });

  test("the injected coordinator seam is actually used", () async {
    final model = newModel();
    settings.wiktionaryPronunciationEnabled = true;
    settings.wiktionaryPronunciationLanguage = "de";
    wiktionary.result = Uint8List.fromList([1]);

    await model.playWord("Haus", mddList: []);

    expect(wiktionary.calls, 1);
    expect(wiktionary.lastLanguage, "de");
  });
}

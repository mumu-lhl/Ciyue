import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/ui/core/word_display/audio_waveform.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

class FakeAudioModel extends AudioModel {
  bool fakePlaying = false;
  String? fakePlayingWord;
  bool stopAudioCalled = false;

  @override
  bool get isPlaying => fakePlaying;

  @override
  String? get playingWord => fakePlayingWord;

  @override
  bool isWordPlaying(String word) {
    if (!fakePlaying || fakePlayingWord == null) return false;
    return fakePlayingWord!.toLowerCase() == word.toLowerCase();
  }

  @override
  Future<void> stopAudio() async {
    stopAudioCalled = true;
    fakePlaying = false;
    fakePlayingWord = null;
    notifyListeners();
  }
}

void main() {
  setUpAll(() async {
    // The widgets read the e-ink setting, which needs the preferences.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  testWidgets("AudioWaveformIcon renders and animates without crashing", (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AudioWaveformIcon(size: 32))),
    );

    expect(find.byType(AudioWaveformIcon), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets("PulsingFab renders child and toggles pulsing animation", (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PulsingFab(
            isPulsing: false,
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );

    expect(find.byType(PulsingFab), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PulsingFab(
            isPulsing: true,
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PulsingFab), findsOneWidget);
  });

  testWidgets(
    "FloatingAudioIndicator displays word and triggers stopAudio when closed",
    (tester) async {
      final fakeModel = FakeAudioModel();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [audioModelProvider.overrideWith((ref) => fakeModel)],
          child: const MaterialApp(
            home: Scaffold(body: FloatingAudioIndicator()),
          ),
        ),
      );

      expect(find.text("sintonico"), findsNothing);

      fakeModel.fakePlaying = true;
      fakeModel.fakePlayingWord = "sintonico";
      fakeModel.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("sintonico"), findsOneWidget);
      expect(find.byType(AudioWaveformIcon), findsOneWidget);

      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pump();

      expect(fakeModel.stopAudioCalled, isTrue);
    },
  );
}

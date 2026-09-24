import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/audio_waveform.dart";
import "package:ciyue/ui/core/word_display/buttons.dart";
import "package:ciyue/viewModels/ai_explanation.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

class FakeAudioModelForButton extends AudioModel {
  bool fakePlaying = false;
  String? fakePlayingWord;
  bool stopAudioCalled = false;
  String? playedWord;

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
  Future<void> playWord(String word, {List<dynamic>? mddList}) async {
    playedWord = word;
    fakePlaying = true;
    fakePlayingWord = word;
    notifyListeners();
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
  testWidgets(
    "Read loudly button toggles from volume_up to AudioWaveformIcon when playing",
    (tester) async {
      final fakeAudioModel = FakeAudioModelForButton();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AudioModel>.value(value: fakeAudioModel),
            ChangeNotifierProvider(create: (_) => AIExplanationModel()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              floatingActionButton: Button(
                word: "sintonico",
                showAIButtons: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Idle state: should show volume_up icon
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byType(AudioWaveformIcon), findsNothing);

      // Tap button to play
      final fab = find.byTooltip("Read Aloud");
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(fakeAudioModel.playedWord, "sintonico");
      expect(fakeAudioModel.fakePlaying, isTrue);

      // Playing state: should now show AudioWaveformIcon inside button
      expect(find.byType(AudioWaveformIcon), findsOneWidget);

      // Tap button again to stop
      await tester.tap(fab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(fakeAudioModel.stopAudioCalled, isTrue);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byType(AudioWaveformIcon), findsNothing);
    },
  );
}

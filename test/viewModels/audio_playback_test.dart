import "package:ciyue/viewModels/audio.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("AudioModel tracks initial playback state correctly", () {
    final model = AudioModel();
    addTearDown(model.dispose);

    expect(model.isPlaying, isFalse);
    expect(model.playingWord, isNull);
    expect(model.isWordPlaying("test"), isFalse);
    expect(AudioModel.instance, equals(model));
  });

  test(
    "isWordPlaying performs case-insensitive match and stopAudio resets state",
    () async {
      final model = AudioModel();
      addTearDown(model.dispose);

      expect(model.isWordPlaying("sintonico"), isFalse);

      model.setPlaybackStateForTesting(isPlaying: true, word: "Sintonico");

      expect(model.isPlaying, isTrue);
      expect(model.playingWord, equals("Sintonico"));
      expect(model.isWordPlaying("sintonico"), isTrue);
      expect(model.isWordPlaying("SINTONICO"), isTrue);
      expect(model.isWordPlaying("other"), isFalse);

      await model.stopAudio();
      expect(model.isPlaying, isFalse);
      expect(model.playingWord, isNull);
      expect(model.isWordPlaying("sintonico"), isFalse);
    },
  );
}

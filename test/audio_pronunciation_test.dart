import "package:ciyue/models/audio.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("pronunciation key candidates try .spx, then .mp3 and .wav", () {
    expect(pronunciationKeyCandidates("apple"), [
      "apple.spx",
      "apple.mp3",
      "apple.wav",
    ]);
  });

  test("pronunciation modes and results are distinct", () {
    expect(PronunciationMode.values, hasLength(3));
    expect(PronunciationResult.values, hasLength(3));
  });
}

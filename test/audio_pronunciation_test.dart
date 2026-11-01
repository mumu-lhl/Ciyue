import "package:ciyue/models/audio.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("pronunciation key candidates try .spx, then .mp3 and .wav", () {
    // MDict stores resource keys with a leading backslash; some packs written
    // by other tools omit it, so both spellings are tried, backslash first.
    expect(pronunciationKeyCandidates("apple"), [
      r"\apple.spx",
      r"\apple.mp3",
      r"\apple.wav",
      "apple.spx",
      "apple.mp3",
      "apple.wav",
    ]);
  });

  test("resourceKeyStem strips the leading separator and extension", () {
    expect(resourceKeyStem(r"\apple.mp3"), "apple");
    expect(resourceKeyStem("apple.mp3"), "apple");
    expect(resourceKeyStem(r"/Apple.SPX"), "apple");
    expect(resourceKeyStem(r"\ID4105989.spx"), "id4105989");
  });

  test("pronunciation modes and results are distinct", () {
    expect(PronunciationMode.values, hasLength(3));
    expect(PronunciationResult.values, hasLength(4));
  });
}

import "package:ciyue/services/long_vowel_lookup.dart";
import "package:test/test.dart";

void main() {
  group("longVowelReadings", () {
    test("writes the mark out as the vowel of the kana before it", () {
      expect(longVowelReadings("フーゾク"), ["ふうぞく"]);
      expect(longVowelReadings("ラーメン"), ["らあめん"]);
      expect(longVowelReadings("コーヒー"), ["こうひい", "こおひい"]);
    });

    test("offers both spellings of a long o", () {
      // A long o is written う (とうきょう) or お (とおきょう), and only a
      // dictionary can say which of the two a given word uses.
      expect(longVowelReadings("オー"), ["おう", "おお"]);
      expect(longVowelReadings("トーキョー").first, "とうきょう");
      expect(longVowelReadings("トーキョー"), hasLength(4));
    });

    test("offers both spellings of a long e", () {
      // Likewise a long e: い (めいる) or え (めえる).
      expect(longVowelReadings("エー"), ["えい", "ええ"]);
      expect(longVowelReadings("メール"), contains("めえる"));
    });

    test("takes the vowel from the small kana of a digraph", () {
      // きょー is きょう: it is the ょ that decides the vowel, not the き.
      expect(longVowelReadings("キョー"), ["きょう", "きょお"]);
    });

    test("reads a hiragana word too", () {
      // The mark is shared between the scripts, and a dictionary may file the
      // word in hiragana, so the input script does not matter.
      expect(longVowelReadings("ふーぞく"), ["ふうぞく"]);
    });

    test("has nothing to offer without a mark", () {
      expect(longVowelReadings("ふうぞく"), isEmpty);
      expect(longVowelReadings("パソコン"), isEmpty);
      expect(longVowelReadings("漢字"), isEmpty);
      expect(longVowelReadings(""), isEmpty);
    });

    test("refuses a mark with no kana before it", () {
      // ン has no vowel, a leading mark has no kana at all, and a second mark
      // follows another mark: any answer would be invented.
      expect(longVowelReadings("ンー"), isEmpty);
      expect(longVowelReadings("ーア"), isEmpty);
      expect(longVowelReadings("オーー"), isEmpty);
      expect(longVowelReadings("ABCー"), isEmpty);
    });

    test("bounds the readings of a pasted run of marks", () {
      final readings = longVowelReadings("オーオーオーオーオー");

      expect(readings, hasLength(maxLongVowelReadings));
      // The most plausible reading is still the first one.
      expect(readings.first, "おうおうおうおうおう");
    });
  });
}

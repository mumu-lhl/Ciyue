import "package:ciyue/services/lookup_keys.dart";
import "package:test/test.dart";

void main() {
  group("caseVariants", () {
    test("keeps the exact spelling first and folds to upper case last", () {
      expect(caseVariants("Abend"), ["Abend", "abend", "ABEND"]);
    });

    test("reaches a capitalised headword from a lower case query", () {
      // The reported case: the dictionary has "Nahida".
      expect(caseVariants("nahida"), ["nahida", "Nahida", "NAHIDA"]);
    });

    test("title-cases every word and hyphen part", () {
      expect(caseVariants("der große bär"), contains("Der Große Bär"));
      expect(caseVariants("four-wheel drive"), contains("Four-Wheel Drive"));
    });

    test("leaves caseless scripts and digits alone", () {
      expect(caseVariants("漢字"), ["漢字"]);
      expect(caseVariants("1984"), ["1984"]);
      expect(caseVariants(""), isEmpty);
    });
  });

  group("kanaVariants", () {
    test("converts hiragana to katakana and back", () {
      expect(kanaVariants("ぱそこん"), ["ぱそこん", "パソコン"]);
      expect(kanaVariants("パソコン"), ["パソコン", "ぱそこん"]);
    });

    test("keeps the long vowel mark", () {
      // フーゾク is ふうぞく in hiragana spelling; expanding the ー needs the
      // vowel of the preceding kana and is left to the suggestions.
      expect(kanaVariants("フーゾク"), ["フーゾク", "ふーぞく"]);
    });

    test("converts the iteration marks too", () {
      expect(kanaVariants("ゝ"), ["ゝ", "ヽ"]);
      expect(kanaVariants("ヽ"), ["ヽ", "ゝ"]);
    });

    test("leaves katakana without a hiragana form alone", () {
      // ヷヸヹヺ have no hiragana counterpart; ・ and ー are shared.
      expect(kanaVariants("ヷ"), ["ヷ"]);
      expect(kanaVariants("・"), ["・"]);
      expect(kanaVariants("漢字"), ["漢字"]);
    });
  });

  group("lookupVariants", () {
    test("puts case variants before kana variants", () {
      expect(lookupVariants("Nahida"), ["Nahida", "nahida", "NAHIDA"]);
      expect(lookupVariants("パソコン"), ["パソコン", "ぱそこん"]);
    });

    test("has nothing to add for a single-spelling word", () {
      expect(lookupVariants("漢字"), ["漢字"]);
      expect(lookupVariants(""), isEmpty);
    });
  });
}

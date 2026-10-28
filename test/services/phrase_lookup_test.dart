import "package:ciyue/services/phrase_lookup.dart";
import "package:test/test.dart";

List<String> Function(String) stemsFrom(Map<String, List<String>> table) {
  return (token) => table[token] ?? const [];
}

void main() {
  group("phraseTokens", () {
    test("splits on whitespace and drops edge punctuation", () {
      expect(phraseTokens("„picked  the phone up.“"), [
        "picked",
        "the",
        "phone",
        "up",
      ]);
    });

    test("keeps punctuation inside a word", () {
      expect(phraseTokens("sieh dir das pick-up an"), [
        "sieh",
        "dir",
        "das",
        "pick-up",
        "an",
      ]);
    });

    test("returns a single token for a single word", () {
      expect(phraseTokens("  Haft "), ["Haft"]);
    });
  });

  group("phraseCandidates", () {
    test("reads an English phrasal verb from its base form", () {
      final candidates = phraseCandidates(
        phraseTokens("picked the phone up"),
        stemsOf: stemsFrom({
          "picked": ["pick"],
        }),
      );

      expect(candidates.first, "pick up");
    });

    test("puts the particle in front for a German separable verb", () {
      final candidates = phraseCandidates(
        phraseTokens("rufe dich an"),
        stemsOf: stemsFrom({
          "rufe": ["rufen"],
        }),
      );

      expect(candidates, contains("anrufen"));
    });

    test("finds the verb when it is not the first word", () {
      // `I picked the phone up` opens with a pronoun; `Ich rufe dich an` puts
      // the verb in second place.
      final candidates = phraseCandidates(
        phraseTokens("I picked the phone up"),
        stemsOf: stemsFrom({
          "picked": ["pick"],
        }),
      );

      expect(candidates, contains("pick up"));
    });

    test("ignores two-word input", () {
      // `picked up` already resolves through the normal lookup's stems.
      expect(
        phraseCandidates(
          phraseTokens("picked up"),
          stemsOf: stemsFrom({
            "picked": ["pick"],
          }),
        ),
        isEmpty,
      );
    });

    test("ignores a paragraph", () {
      final paragraph = List.filled(maxPhraseWords + 1, "word").join(" ");
      expect(
        phraseCandidates(phraseTokens(paragraph), stemsOf: (_) => const []),
        isEmpty,
      );
    });

    test("falls back to the spelling that was typed", () {
      final candidates = phraseCandidates(
        phraseTokens("picked the phone up"),
        stemsOf: (_) => const [],
      );

      expect(candidates, contains("picked up"));
    });
  });
}

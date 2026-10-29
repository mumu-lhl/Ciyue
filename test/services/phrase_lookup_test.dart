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

    test("ignores a single word", () {
      // One token can never be a split phrasal verb; the lower bound is now
      // two words so only a single word is still rejected.
      expect(
        phraseCandidates(phraseTokens("Haft"), stemsOf: (_) => const []),
        isEmpty,
      );
    });

    test("handles a two-word German separable verb", () {
      // `siehst fern` stems to `sehen fern`, but the dictionary form is
      // `fernsehen`. Two-word phrases are now in scope to cover this.
      final candidates = phraseCandidates(
        phraseTokens("siehst fern"),
        stemsOf: stemsFrom({
          "siehst": ["sehen"],
        }),
      );

      expect(candidates, contains("fernsehen"));
    });

    test("handles a two-word English phrasal verb", () {
      // `picked up` now reaches this pass too; it should still resolve to
      // `pick up` from its stem.
      final candidates = phraseCandidates(
        phraseTokens("picked up"),
        stemsOf: stemsFrom({
          "picked": ["pick"],
        }),
      );

      expect(candidates, contains("pick up"));
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

import "package:ciyue/services/word_split.dart";
import "package:test/test.dart";

/// A resolver over a fixed vocabulary, case-insensitive like the real lookup:
/// a query typed as `cover` still resolves to the stored `Cover`.
String? Function(String) resolverOf(Iterable<String> words) {
  final byLowercase = {for (final word in words) word.toLowerCase(): word};
  return (candidate) => byLowercase[candidate.toLowerCase()];
}

void main() {
  group("findSplits", () {
    test("splits a German compound, swallowing the linking s", () {
      final splits = findSplits(
        "Wohnzimmerschrank",
        resolve: resolverOf(["Wohnzimmer", "Schrank"]),
      );

      expect(splits, isNotEmpty);
      // `Wohnzimmers` is not a word: the `s` only exists inside the compound,
      // so the split is only reachable if the linker is consumed.
      expect(splits.first.display, "Wohnzimmer + Schrank");
    });

    test("splits an ordinary German compound past 32 characters", () {
      // 36 characters, nothing exotic, and a word a reader really does stop
      // to look up — yet it was refused while the ceiling was lower.
      final splits = findSplits(
        "Kraftfahrzeughaftpflichtversicherung",
        resolve: resolverOf(["Kraftfahrzeug", "haftpflicht", "versicherung"]),
      );

      expect(splits.first.parts, [
        "Kraftfahrzeug",
        "haftpflicht",
        "versicherung",
      ]);
    });

    test("splits six parts of the longest German compound asked about", () {
      // The bound-setting case: 63 characters, six parts, with `s`, `s`, `n`
      // and `s` swallowed between them.
      final splits = findSplits(
        "Rindfleischetikettierungsüberwachungsaufgabenübertragungsgesetz",
        resolve: resolverOf([
          "Rindfleisch",
          "etikettierung",
          "überwachung",
          "aufgabe",
          "übertragung",
          "gesetz",
        ]),
      );

      expect(splits.first.parts, [
        "Rindfleisch",
        "etikettierung",
        "überwachung",
        "aufgabe",
        "übertragung",
        "gesetz",
      ]);
    });

    test("splits a run of Chinese characters both ways", () {
      final splits = findSplits(
        "倾奇者",
        resolve: resolverOf(["倾奇", "者", "倾", "奇"]),
      );

      expect(splits.map((split) => split.display), ["倾奇 + 者", "倾 + 奇 + 者"]);
    });

    test("shows the spelling the dictionary uses, not the query", () {
      final splits = findSplits(
        "animecover",
        resolve: resolverOf(["Anime", "Cover"]),
      );

      expect(splits.first.parts, ["Anime", "Cover"]);
    });

    test("prefers fewer parts", () {
      // Both `Dampf + schiff + fahrt` and `Dampfschiff + fahrt` are derivable;
      // the two-part reading is the one worth showing first.
      final splits = findSplits(
        "Dampfschifffahrt",
        resolve: resolverOf(["Dampf", "schiff", "fahrt", "Dampfschiff"]),
      );

      expect(splits.first.display, "Dampfschiff + fahrt");
      expect(splits.map((split) => split.parts.length), contains(3));
    });

    test("returns nothing when the word is one headword", () {
      expect(findSplits("Cover", resolve: resolverOf(["Cover"])), isEmpty);
    });

    test("returns nothing when a part would be shorter than two letters", () {
      // `X + bend` is not a reading anyone wants, and the single letter is the
      // only way to cover the word.
      expect(findSplits("Xbend", resolve: resolverOf(["X", "bend"])), isEmpty);
    });

    test("allows single-character parts in Chinese", () {
      final splits = findSplits("我爱你", resolve: resolverOf(["我", "爱", "你"]));

      expect(splits.single.display, "我 + 爱 + 你");
    });

    test("splits into six parts", () {
      final parts = ["aa", "bb", "cc", "dd", "ee", "ff"];
      expect(
        findSplits(parts.join(), resolve: resolverOf(parts)).single.display,
        "aa + bb + cc + dd + ee + ff",
      );
    });

    test("gives up beyond six parts", () {
      final parts = ["aa", "bb", "cc", "dd", "ee", "ff", "gg"];
      expect(findSplits(parts.join(), resolve: resolverOf(parts)), isEmpty);
    });

    test("ignores input that is too short or too long", () {
      expect(findSplits("ab", resolve: resolverOf(["a", "b"])), isEmpty);
      expect(
        findSplits("a" * (maxSplitLength + 1), resolve: resolverOf(["a"])),
        isEmpty,
      );
    });

    test("does not apply the German linkers outside the Latin alphabet", () {
      // `самолет` would split into `само + лет`; the `о` that follows is part
      // of the second word, not a linking morpheme, and the linker table must
      // not be consulted for a Cyrillic word.
      final splits = findSplits("самолет", resolve: resolverOf(["самолет"]));

      expect(splits, isEmpty);
    });
  });

  group("splitCandidates", () {
    test("covers the slices a split can use, without the whole word", () {
      final candidates = splitCandidates("Animecover");

      expect(candidates, contains("Anime"));
      // The candidates are slices of the query, so they keep its spelling;
      // the dictionary's own spelling only appears in the result.
      expect(candidates, contains("cover"));
      expect(candidates, isNot(contains("Animecover")));
    });

    test("keeps single characters for CJK but not for Latin", () {
      expect(splitCandidates("倾奇者"), contains("倾"));
      expect(splitCandidates("Animecover"), isNot(contains("A")));
    });

    test("is empty outside the supported length", () {
      expect(splitCandidates("ab"), isEmpty);
      expect(splitCandidates("a" * (maxSplitLength + 1)), isEmpty);
    });

    test("every returned slice really occurs in the word", () {
      const word = "Dampfschifffahrt";
      for (final candidate in splitCandidates(word)) {
        expect(word.contains(candidate), isTrue, reason: candidate);
      }
    });
  });
}

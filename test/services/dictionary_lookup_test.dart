import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/services/hunspell.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:test/test.dart";

void main() {
  test("disabled morphology keeps exact lookup only", () async {
    final morphology = FakeMorphology(stemsResult: ["rim"]);
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"rims": "rims content", "rim": "rim content"},
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: morphology,
      enabled: false,
    );

    final result = await lookup.lookup("rims");

    expect(result.entriesFor(1).map((entry) => entry.headword), ["rims"]);
    expect(morphology.stemCalls, 0);
  });

  test("fallback mode uses stems when the original is absent", () async {
    final morphology = FakeMorphology(stemsResult: ["rim", "unlisted"]);
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"rim": "rim content"},
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: morphology,
      enabled: true,
      mode: HunspellLookupMode.fallback,
    );

    final result = await lookup.lookup("rims");

    expect(result.entriesFor(1).map((entry) => entry.headword), ["rim"]);
    expect(morphology.stemCalls, 1);
  });

  test("fallback mode does not add stems when the original exists", () async {
    final morphology = FakeMorphology(stemsResult: ["rim"]);
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"rims": "rims content", "rim": "rim content"},
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: morphology,
      enabled: true,
      mode: HunspellLookupMode.fallback,
    );

    final result = await lookup.lookup("rims");

    expect(result.entriesFor(1).map((entry) => entry.headword), ["rims"]);
  });

  test("supplement mode returns all matching stems in order", () async {
    final morphology = FakeMorphology(
      stemsResult: ["rim", "rim", "rims", "edge"],
    );
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {
        "rims": "rims content",
        "rim": "rim content",
        "edge": "edge content",
      },
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: morphology,
      enabled: true,
      mode: HunspellLookupMode.supplement,
    );

    final result = await lookup.lookup("rims");

    expect(result.entriesFor(1).map((entry) => entry.headword), [
      "rims",
      "rim",
      "edge",
    ]);
  });

  test(
    "search suggestions append matching stems after prefix results",
    () async {
      final morphology = FakeMorphology(stemsResult: ["rim"]);
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"rims": "rims content", "rim": "rim content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: morphology,
        enabled: true,
        mode: HunspellLookupMode.supplement,
      );

      final result = await lookup.searchSuggestions("rims");

      expect(result.dictionarySuggestions, ["rims", "rim"]);
      expect(result.spellingSuggestions, isEmpty);
    },
  );

  test("adds spelling suggestions when a dictionary does not match", () async {
    final morphology = FakeMorphology(
      stemsResult: const [],
      suggestionsResult: ["unprecedented", "unrepresented"],
    );
    final dictionary = FakeDictionarySource(id: 1, entries: {});
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: morphology,
      enabled: true,
    );

    final result = await lookup.searchSuggestions("unpresidented");

    expect(result.dictionarySuggestions, isEmpty);
    expect(result.spellingSuggestions, ["unprecedented", "unrepresented"]);
    expect(morphology.suggestionCalls, 1);
  });

  test(
    "does not add spelling suggestions when every dictionary matches",
    () async {
      final morphology = FakeMorphology(
        stemsResult: const [],
        suggestionsResult: ["wording"],
      );
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"word": "word content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: morphology,
        enabled: true,
      );

      final result = await lookup.searchSuggestions("word");

      expect(result.dictionarySuggestions, ["word"]);
      expect(result.spellingSuggestions, isEmpty);
      expect(morphology.suggestionCalls, 0);
    },
  );

  test("a lower case query reaches a capitalised headword", () async {
    // Reporting case: the dictionary stores "Nahida", the user types "nahida".
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"Nahida": "nahida content"},
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: FakeMorphology(stemsResult: const []),
      enabled: false,
    );

    final result = await lookup.lookup("nahida");

    expect(result.entriesFor(1).map((entry) => entry.headword), ["Nahida"]);
  });

  test("both spellings are kept when the dictionary has two", () async {
    // German minimal pairs: Weg/weg and Essen/essen are different words, so
    // neither spelling may be dropped.
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"abend": "lower", "Abend": "capitalised"},
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: FakeMorphology(stemsResult: const []),
      enabled: false,
    );

    expect(
      (await lookup.lookup("abend")).entriesFor(1).map((e) => e.headword),
      ["abend", "Abend"],
    );
    expect(
      (await lookup.lookup("Abend")).entriesFor(1).map((e) => e.headword),
      ["Abend", "abend"],
    );
  });

  test("kana variants reach a katakana headword", () async {
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"パソコン": "pc content"},
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: FakeMorphology(stemsResult: const []),
      enabled: false,
    );

    final result = await lookup.lookup("ぱそこん");

    expect(result.entriesFor(1).map((entry) => entry.headword), ["パソコン"]);
  });

  test("morphology results stay behind the spelling variants", () async {
    final morphology = FakeMorphology(stemsResult: ["Abend", "abends"]);
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"abend": "lower", "Abend": "capitalised", "abends": "stem"},
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: morphology,
      enabled: true,
      mode: HunspellLookupMode.supplement,
    );

    final result = await lookup.lookup("abend");

    expect(result.entriesFor(1).map((entry) => entry.headword), [
      "abend",
      "Abend",
      "abends",
    ]);
  });

  group("suggestions for an unmatched word", () {
    test("splits a compound using the whole group", () async {
      // The parts live in different dictionaries, which is normal for a group
      // that pairs a monolingual dictionary with a bilingual one.
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"Anime": "Anime content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        others: [
          FakeDictionarySource(id: 2, entries: {"Cover": "Cover content"}),
        ],
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      final splits = await lookup.wordSplitsFor("Animecover");

      expect(splits.first.display, "Anime + Cover");
    });

    test("splitting never waits for Hunspell", () async {
      // The page draws the splits first precisely because `suggest` is two
      // orders of magnitude slower, so this path must not touch morphology.
      final morphology = FakeMorphology(
        stemsResult: const [],
        suggestionsResult: const ["abschieben"],
      );
      final lookup = makeLookup(
        dictionary: FakeDictionarySource(
          id: 1,
          entries: {"Anime": "Anime content", "Cover": "Cover"},
        ),
        morphology: morphology,
        enabled: true,
      );

      final splits = await lookup.wordSplitsFor("Animecover");

      expect(splits, isNotEmpty);
      expect(morphology.suggestionCalls, 0);
    });

    test("keeps only the spelling suggestions a dictionary can open", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"abschieben": "abschieben content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(
          stemsResult: const [],
          suggestionsResult: const ["abschieben", "abschiessen"],
        ),
        enabled: true,
      );

      final suggestions = await lookup.spellingSuggestionsFor("abgeschoben");

      // `abschiessen` exists in no dictionary: suggesting it would only lead
      // to another "not found" page.
      expect(suggestions, ["abschieben"]);
    });

    test("shows the spelling the dictionary files the word under", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"Diktionär": "Diktionär content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(
          stemsResult: const [],
          suggestionsResult: const ["diktionär"],
        ),
        enabled: true,
      );

      final suggestions = await lookup.spellingSuggestionsFor("Diktioonar");

      expect(suggestions, ["Diktionär"]);
    });

    test("a broken dictionary does not stop the others", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"Anime": "Anime content", "Cover": "Cover content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        others: [FakeDictionarySource(id: 2, entries: const {}, throws: true)],
        morphology: FakeMorphology(
          stemsResult: const [],
          suggestionsResult: const ["abschieben"],
        ),
        enabled: true,
      );

      expect(
        (await lookup.wordSplitsFor("Animecover")).first.display,
        "Anime + Cover",
      );
      // No dictionary holds `abschieben`, and the broken one cannot say.
      expect(await lookup.spellingSuggestionsFor("Animecover"), isEmpty);
    });

    test("still splits when morphology is switched off", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"倾奇": "倾奇 content", "者": "者 content"},
      );
      final morphology = FakeMorphology(
        stemsResult: const [],
        suggestionsResult: const ["倾奇者"],
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: morphology,
        enabled: false,
      );

      expect((await lookup.wordSplitsFor("倾奇者")).first.display, "倾奇 + 者");
      expect(await lookup.spellingSuggestionsFor("倾奇者"), isEmpty);
      expect(morphology.suggestionCalls, 0);
    });

    test("returns nothing for input worth no suggestions", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"Cover": "Cover content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      expect(await lookup.wordSplitsFor(""), isEmpty);
      expect(await lookup.spellingSuggestionsFor(""), isEmpty);
      // One part is what already failed; there is nothing to offer.
      expect(await lookup.wordSplitsFor("Cover"), isEmpty);
    });
  });
}

DictionaryLookup makeLookup({
  required FakeDictionarySource dictionary,
  required FakeMorphology morphology,
  required bool enabled,
  HunspellLookupMode mode = HunspellLookupMode.fallback,
  List<FakeDictionarySource> others = const [],
}) {
  return DictionaryLookup(
    dictionaries: () => [dictionary, ...others],
    morphology: morphology,
    morphologyEnabled: () => enabled,
    lookupMode: () => mode,
  );
}

class FakeMorphology implements MorphologyProvider {
  final List<String> stemsResult;
  final List<String> suggestionsResult;
  int stemCalls = 0;
  int suggestionCalls = 0;

  FakeMorphology({
    required this.stemsResult,
    this.suggestionsResult = const [],
  });

  @override
  Future<List<String>> stems(String word) async {
    stemCalls++;
    return stemsResult;
  }

  @override
  Future<List<String>> suggestions(String word) async {
    suggestionCalls++;
    return suggestionsResult;
  }
}

class FakeDictionarySource implements DictionarySource {
  @override
  final int id;
  final Map<String, String> entries;

  /// Simulates a dictionary that fails to load or read.
  final bool throws;

  FakeDictionarySource({
    required this.id,
    required this.entries,
    this.throws = false,
  });

  @override
  Future<String?> resolveExactKey(String word) async {
    if (throws) throw StateError("dictionary is broken");
    // Same order as the real implementations: the spelling as typed first,
    // then the case/kana variants of it.
    for (final candidate in lookupVariants(word)) {
      if (entries.containsKey(candidate)) return candidate;
    }
    return null;
  }

  @override
  Future<Map<String, String>> resolveKeys(Iterable<String> words) async {
    if (throws) throw StateError("dictionary is broken");
    final resolved = <String, String>{};
    for (final word in words) {
      final key = await resolveExactKey(word);
      if (key != null) resolved[word] = key;
    }
    return resolved;
  }

  @override
  Future<List<String>> search(String query) async {
    return entries.keys.where((key) => key.startsWith(query)).toList();
  }

  @override
  Future<List<DictionaryEntryData>> readExactEntries(
    Iterable<String> words,
  ) async {
    final result = <DictionaryEntryData>[];
    final seen = <String>{};
    for (final word in words) {
      final key = await resolveExactKey(word);
      if (key != null && seen.add(key)) {
        result.add(DictionaryEntryData(headword: key, content: entries[key]!));
      }
    }
    return result;
  }
}

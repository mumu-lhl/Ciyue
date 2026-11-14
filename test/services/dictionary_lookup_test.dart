import "dart:io";

import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/models/search_mode.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/services/full_text_index_builder.dart";
import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search_service.dart";
import "package:ciyue/services/hunspell.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/services/phrase_lookup.dart" show maxPhraseWords;
import "package:ciyue/services/word_split.dart";
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

  test("lookup passes the resolved exact key to readExactEntries", () async {
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
    // The query spelling itself was already resolved above, so only its
    // remaining variants are resolved again inside the read: "rims" has
    // six lookup variants (three cases times two widths), one of which is
    // covered by the resolved key.
    expect(dictionary.lastResolvedKeys, {"rims": "rims"});
    expect(dictionary.lastResolveCalls, 5);
  });

  test("lookup passes no resolved keys when the word is absent", () async {
    final morphology = FakeMorphology(stemsResult: const []);
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"rim": "rim content"},
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: morphology,
      enabled: false,
    );

    final result = await lookup.lookup("rims");

    expect(result.entriesFor(1), isEmpty);
    expect(dictionary.lastResolvedKeys, isNull);
  });

  test("readExactEntries reads each distinct headword once", () async {
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"rims": "rims content", "rim": "rim content"},
    );

    final entries = await dictionary.readExactEntries([
      "rims",
      "Rims",
      "RIMS",
      "rim",
    ]);

    expect(entries.map((entry) => entry.headword), ["rims", "rim"]);
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

    test("reads an English phrasal verb out of a phrase", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"pick up": "pick up content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(
          stemsResult: const [],
          stemsByWord: const {
            "picked": ["pick"],
          },
        ),
        enabled: true,
      );

      expect(await lookup.phraseSuggestionsFor("picked the phone up"), [
        "pick up",
      ]);
    });

    test("reads a German separable verb out of a phrase", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"anrufen": "anrufen content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(
          stemsResult: const [],
          stemsByWord: const {
            "rufe": ["rufen"],
          },
        ),
        enabled: true,
      );

      expect(await lookup.phraseSuggestionsFor("rufe dich an"), ["anrufen"]);
    });

    test("reads a two-word German separable verb", () async {
      // `sehe an` stems to `sehen an`, but the headword is `ansehen`: the
      // normal lookup never drops the space, so this pass has to join them.
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"ansehen": "ansehen content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(
          stemsResult: const [],
          stemsByWord: const {
            "sehe": ["sehen"],
          },
        ),
        enabled: true,
      );

      expect(await lookup.phraseSuggestionsFor("sehe an"), ["ansehen"]);
    });

    test("reads a two-word English phrasal verb", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"pick up": "pick up content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(
          stemsResult: const [],
          stemsByWord: const {
            "picked": ["pick"],
          },
        ),
        enabled: true,
      );

      expect(await lookup.phraseSuggestionsFor("picked up"), ["pick up"]);
    });

    test("a pasted paragraph costs no stem calls", () async {
      final morphology = FakeMorphology(stemsResult: const []);
      final lookup = makeLookup(
        dictionary: FakeDictionarySource(id: 1, entries: const {}),
        morphology: morphology,
        enabled: true,
      );

      final paragraph = List.filled(maxPhraseWords + 1, "word").join(" ");
      expect(await lookup.phraseSuggestionsFor(paragraph), isEmpty);
      expect(morphology.stemCalls, 0);
    });

    test("splitting ignores a phrase", () async {
      // Every word is a headword, so an unguarded split would answer
      // `picked + the + phone + up`.
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {
          "picked": "picked",
          "the": "the",
          "phone": "phone",
          "up": "up",
        },
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      expect(await lookup.wordSplitsFor("picked the phone up"), isEmpty);
    });

    test("reads a katakana long vowel as hiragana", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"ふうぞく": "ふうぞく content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      expect(await lookup.longVowelSuggestionsFor("フーゾク"), ["ふうぞく"]);
    });

    test("keeps the long-vowel readings a dictionary has", () async {
      // A long o is おう or おお, and only the dictionary knows which of them
      // the word uses: 大阪 is おおさか even though オーサカ suggests otherwise.
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"おおさか": "おおさか content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      expect(await lookup.longVowelSuggestionsFor("オーサカ"), ["おおさか"]);
    });

    test(
      "offers every reading the dictionaries can open, best first",
      () async {
        final dictionary = FakeDictionarySource(
          id: 1,
          entries: {"とうきょう": "とうきょう content", "とおきょう": "とおきょう content"},
        );
        final lookup = makeLookup(
          dictionary: dictionary,
          morphology: FakeMorphology(stemsResult: const []),
          enabled: false,
        );

        expect(await lookup.longVowelSuggestionsFor("トーキョー"), [
          "とうきょう",
          "とおきょう",
        ]);
      },
    );

    test(
      "shows the katakana spelling the dictionary files the word under",
      () async {
        // `resolveKeys` also tries the other kana script, so an expansion that
        // lands on a katakana headword comes back in katakana.
        final dictionary = FakeDictionarySource(
          id: 1,
          entries: {"フウゾク": "フウゾク content"},
        );
        final lookup = makeLookup(
          dictionary: dictionary,
          morphology: FakeMorphology(stemsResult: const []),
          enabled: false,
        );

        expect(await lookup.longVowelSuggestionsFor("フーゾク"), ["フウゾク"]);
      },
    );

    test("long vowels need neither morphology nor a mark", () async {
      final morphology = FakeMorphology(
        stemsResult: const [],
        suggestionsResult: const ["ふうぞく"],
      );
      final lookup = makeLookup(
        dictionary: FakeDictionarySource(
          id: 1,
          entries: {"ふうぞく": "ふうぞく content"},
        ),
        morphology: morphology,
        enabled: true,
      );

      // Nothing to read without a mark, and nothing that costs a Hunspell call.
      expect(await lookup.longVowelSuggestionsFor("ふうぞく"), isEmpty);
      expect(await lookup.longVowelSuggestionsFor("フーゾク"), ["ふうぞく"]);
      expect(morphology.stemCalls, 0);
      expect(morphology.suggestionCalls, 0);
    });

    test("a phrase needs no morphology to match what was typed", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"picked up": "picked up content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      expect(await lookup.phraseSuggestionsFor("picked the phone up"), [
        "picked up",
      ]);
    });
  });

  group("prefix suggestions: cancellation, timeout, cache (P0-3/P0-4)", () {
    test("an exact repeat answers from the cache without searching", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"rims": "rims content", "rim": "rim content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      final first = await lookup.searchSuggestions("rims");
      final second = await lookup.searchSuggestions("rims");

      expect(first.dictionarySuggestions, ["rims"]);
      expect(second.dictionarySuggestions, ["rims"]);
      // One query costs two `search` calls (half- and full-width variants),
      // so the cached repeat is 2 total: the first query searched, the
      // second did not.
      expect(dictionary.searchCalls, 2);
    });

    test("a longer query filters the previous keystroke's results", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {
          "rim": "rim content",
          "rims": "rims content",
          "ripe": "ripe content",
        },
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      expect((await lookup.searchSuggestions("ri")).dictionarySuggestions, [
        "rim",
        "rims",
        "ripe",
      ]);
      expect((await lookup.searchSuggestions("rim")).dictionarySuggestions, [
        "rim",
        "rims",
      ]);
      expect((await lookup.searchSuggestions("rims")).dictionarySuggestions, [
        "rims",
      ]);
      // A longer query with no match is still answered from the cache:
      // every "rix…" headword would have been among the "ri" results.
      expect(
        (await lookup.searchSuggestions("rix")).dictionarySuggestions,
        isEmpty,
      );
      // Four keystrokes, but only the first searched (twice, once per width
      // variant); the rest were filtered from its cached prefix results.
      expect(dictionary.searchCalls, 2);
    });

    test("switching the dictionary set invalidates the cache", () async {
      var dicts = [
        FakeDictionarySource(id: 1, entries: {"apple": "apple content"}),
      ];
      final lookup = DictionaryLookup(
        dictionaries: () => dicts,
        morphology: FakeMorphology(stemsResult: const []),
        morphologyEnabled: () => false,
        lookupMode: () => HunspellLookupMode.fallback,
      );

      expect((await lookup.searchSuggestions("app")).dictionarySuggestions, [
        "apple",
      ]);

      // Same id, new instance (a re-enabled dictionary): the cached answer
      // belongs to the old instance and must not be served.
      dicts = [
        FakeDictionarySource(
          id: 1,
          entries: {"application": "application content"},
        ),
      ];
      expect((await lookup.searchSuggestions("app")).dictionarySuggestions, [
        "application",
      ]);
      // The new dictionary was searched once: twice for its two width
      // variants, and never for the old instance's cached answer.
      expect(dicts.single.searchCalls, 2);
    });

    test(
      "a slow stems call times out instead of stalling suggestions",
      () async {
        final morphology = FakeMorphology(
          stemsResult: ["rim"],
          stemsDelay: const Duration(milliseconds: 600),
        );
        final lookup = makeLookup(
          dictionary: FakeDictionarySource(id: 1, entries: {"rims": "rims"}),
          others: [
            FakeDictionarySource(id: 2, entries: {"rim": "rim"}),
          ],
          morphology: morphology,
          enabled: true,
          mode: HunspellLookupMode.supplement,
        );

        final stopwatch = Stopwatch()..start();
        final result = await lookup.searchSuggestions("rims");
        stopwatch.stop();

        // The stem "rim" would resolve in the second dictionary if it had
        // arrived; the timeout drops it, and the dictionary result stands.
        expect(result.dictionarySuggestions, ["rims"]);
        expect(stopwatch.elapsedMilliseconds, lessThan(900));
        expect(morphology.stemCalls, 1);
      },
    );

    test(
      "a slow spelling call times out and keeps the dictionary results",
      () async {
        final lookup = makeLookup(
          dictionary: FakeDictionarySource(
            id: 1,
            entries: {"apple": "apple content"},
          ),
          morphology: FakeMorphology(
            stemsResult: const [],
            suggestionsResult: const ["apples"],
            suggestionsDelay: const Duration(milliseconds: 600),
          ),
          enabled: true,
        );

        final stopwatch = Stopwatch()..start();
        final result = await lookup.searchSuggestions("appl");
        stopwatch.stop();

        // A Hunspell timeout is not "no dictionary match": the prefix
        // result is untouched, only the spelling tail is dropped.
        expect(result.dictionarySuggestions, ["apple"]);
        expect(result.spellingSuggestions, isEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(900));
      },
    );

    test("a superseded keystroke stops before the Hunspell stages", () async {
      final morphology = FakeMorphology(stemsResult: ["rim"]);
      final lookup = makeLookup(
        dictionary: FakeDictionarySource(
          id: 1,
          entries: {"rims": "rims"},
          searchDelay: const Duration(milliseconds: 300),
        ),
        others: [
          FakeDictionarySource(
            id: 2,
            entries: {"rim": "rim"},
            searchDelay: const Duration(milliseconds: 300),
          ),
        ],
        morphology: morphology,
        enabled: true,
        mode: HunspellLookupMode.supplement,
      );

      final first = lookup.searchSuggestions("rims");
      await Future.delayed(const Duration(milliseconds: 10));
      final second = lookup.searchSuggestions("rims");

      // The first keystroke's prefix search finished after the second
      // arrived: it hands back the prefix matches instead of running the
      // stem stages for a query nobody is looking at any more.
      expect((await first).dictionarySuggestions, ["rims"]);
      expect((await second).dictionarySuggestions, ["rims", "rim"]);
      expect(morphology.stemCalls, 1);
    });
  });

  group("word splits: staged probing (P1-13)", () {
    test("probes only slices starting where a part can begin", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"Anime": "Anime content", "Cover": "Cover content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      final splits = await lookup.wordSplitsFor("Animecover");

      expect(splits.first.display, "Anime + Cover");
      final probed = dictionary.resolveKeysBatchSizes.fold<int>(
        0,
        (total, batch) => total + batch,
      );
      // Prefixes of the word (8) plus the slices starting where "Anime"
      // ends (4) — not the whole O(n²) set.
      expect(probed, 12);
      expect(probed, lessThan(splitCandidates("Animecover").length));
    });

    test("splits still swallow the linking s", () async {
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"Wohnzimmer": "Wohnzimmer", "Schrank": "Schrank"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      final splits = await lookup.wordSplitsFor("Wohnzimmerschrank");

      expect(splits.first.display, "Wohnzimmer + Schrank");
    });
  });

  test("a failing morphology does not take the lookup down", () async {
    final lookup = makeLookup(
      dictionary: FakeDictionarySource(
        id: 1,
        entries: {"rims": "rims content"},
      ),
      morphology: FakeMorphology(stemsResult: const [], stemsThrow: true),
      enabled: true,
      mode: HunspellLookupMode.supplement,
    );

    final result = await lookup.lookup("rims");

    // The exact entry still comes back; only the stem candidates are missing.
    expect(result.entriesFor(1).map((entry) => entry.headword), ["rims"]);
  });

  group("search mode dispatch (issue #824)", () {
    const ftsRows = [
      FullTextIndexRow(rowid: 1, headword: "中国", body: "中国是一个国家"),
      FullTextIndexRow(rowid: 2, headword: "中华民国", body: "历史上的国家"),
      FullTextIndexRow(rowid: 3, headword: "中华人民共和国", body: "成立于1949年"),
      FullTextIndexRow(rowid: 4, headword: "中华", body: "中华民族"),
      FullTextIndexRow(rowid: 5, headword: "美国", body: "美利坚合众国"),
      FullTextIndexRow(rowid: 6, headword: "读者", body: "本を読む人"),
      FullTextIndexRow(rowid: 7, headword: "作者", body: "本を書く人"),
      FullTextIndexRow(rowid: 8, headword: "運動", body: "体を動かすこと"),
      FullTextIndexRow(rowid: 9, headword: "行動", body: "行動すること"),
      FullTextIndexRow(rowid: 10, headword: "動詞", body: "品詞の一つ"),
    ];

    test("suffix mode returns headwords ending with the query", () async {
      final service = await makeFtsService(ftsRows);
      final lookup = makeLookup(
        dictionary: FakeDictionarySource(id: 1, entries: const {}),
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      final chinese = await lookup.searchSuggestions(
        "者",
        mode: SearchMode.suffix,
        fullText: service,
      );
      expect(chinese.dictionarySuggestions, containsAll(["读者", "作者"]));

      final japanese = await lookup.searchSuggestions(
        "動",
        mode: SearchMode.suffix,
        fullText: service,
      );
      expect(japanese.dictionarySuggestions, containsAll(["運動", "行動"]));
      expect(japanese.dictionarySuggestions, isNot(contains("動詞")));
    });

    test("multi-word mode matches non-adjacent headword characters", () async {
      final service = await makeFtsService(ftsRows);
      final lookup = makeLookup(
        dictionary: FakeDictionarySource(id: 1, entries: const {}),
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      final result = await lookup.searchSuggestions(
        "中国",
        mode: SearchMode.multiWord,
        fullText: service,
      );
      expect(
        result.dictionarySuggestions,
        containsAll(["中国", "中华民国", "中华人民共和国"]),
      );
      expect(result.dictionarySuggestions, isNot(contains("中华")));
      expect(result.dictionarySuggestions, isNot(contains("美国")));
    });

    test("full-text mode returns definition hits, not headwords", () async {
      final service = await makeFtsService(ftsRows);
      final lookup = makeLookup(
        dictionary: FakeDictionarySource(id: 1, entries: const {}),
        morphology: FakeMorphology(stemsResult: const []),
        enabled: false,
      );

      final result = await lookup.searchSuggestions(
        "国家",
        mode: SearchMode.fullText,
        fullText: service,
      );
      expect(result.dictionarySuggestions, isEmpty);
      expect(
        result.fullTextHits.map((hit) => hit.headword),
        containsAll(["中国", "中华民国"]),
      );
      expect(result.fullTextIndexStatus, FullTextIndexStatus.ready);
    });

    test(
      "an FTS mode without a service reports not-built, not empty",
      () async {
        final lookup = makeLookup(
          dictionary: FakeDictionarySource(id: 1, entries: const {}),
          morphology: FakeMorphology(stemsResult: const []),
          enabled: false,
        );

        final result = await lookup.searchSuggestions(
          "者",
          mode: SearchMode.suffix,
        );
        expect(result.dictionarySuggestions, isEmpty);
        expect(result.fullTextIndexStatus, FullTextIndexStatus.notBuilt);
      },
    );

    test("prefix mode is the default and keeps its behaviour", () async {
      final lookup = makeLookup(
        dictionary: FakeDictionarySource(
          id: 1,
          entries: {"rims": "rims content", "rim": "rim content"},
        ),
        morphology: FakeMorphology(stemsResult: ["rim"]),
        enabled: true,
        mode: HunspellLookupMode.supplement,
      );

      final result = await lookup.searchSuggestions("rims");

      expect(result.dictionarySuggestions, ["rims", "rim"]);
      expect(result.fullTextIndexStatus, FullTextIndexStatus.ready);
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

/// A real [FullTextSearchService] over canned rows, so mode dispatch can
/// be tested without a dictionary file: the fake runner feeds [rows]
/// straight into the store instead of reading a dictionary.
Future<FullTextSearchService> makeFtsService(
  List<FullTextIndexRow> rows,
) async {
  final dir = await Directory.systemTemp.createTemp("search_mode_lookup_");
  final mdxFile = File("${dir.path}/dict.mdx");
  await mdxFile.writeAsBytes([1, 2, 3, 4]);
  final dictionary = _FtsFakeDictionary(
    id: 1,
    type: 1,
    path: "${dir.path}/dict",
  );
  final service = FullTextSearchService(
    dictionaries: () => [dictionary],
    knownIds: () async => {1},
    databaseDirectory: () async => dir.path,
    runner:
        (
          FullTextBuildRequest request, {
          required Future<void> Function(List<FullTextIndexRow>, int, int)
          onBatch,
          required Future<void> Function(int) onTotal,
          required FullTextBuildCancelToken cancelToken,
        }) async {
          await onTotal(rows.length);
          for (final row in rows) {
            await onBatch([row], row.rowid, rows.length);
          }
        },
  );
  await service.ensureBuilt(dictionary);
  addTearDown(() async {
    service.dispose();
    await dir.delete(recursive: true);
  });
  return service;
}

class _FtsFakeDictionary implements LoadedDictionary {
  @override
  final int id;
  @override
  final int type;
  @override
  final String path;

  _FtsFakeDictionary({
    required this.id,
    required this.type,
    required this.path,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMorphology implements MorphologyProvider {
  final List<String> stemsResult;
  final List<String> suggestionsResult;

  /// Per-token answers, for tests that stem a whole phrase.
  final Map<String, List<String>> stemsByWord;
  int stemCalls = 0;
  int suggestionCalls = 0;
  bool stemsThrow;

  /// Artificial latency, for the timeout tests: a Hunspell call slower
  /// than the suggestion timeout must degrade to empty, not stall the list.
  final Duration stemsDelay;
  final Duration suggestionsDelay;

  FakeMorphology({
    required this.stemsResult,
    this.suggestionsResult = const [],
    this.stemsByWord = const {},
    this.stemsThrow = false,
    this.stemsDelay = Duration.zero,
    this.suggestionsDelay = Duration.zero,
  });

  @override
  Future<List<String>> stems(String word) async {
    stemCalls++;
    if (stemsThrow) throw StateError("hunspell worker is gone");
    await Future.delayed(stemsDelay);
    return stemsByWord[word] ?? stemsResult;
  }

  @override
  Future<List<String>> suggestions(String word) async {
    suggestionCalls++;
    await Future.delayed(suggestionsDelay);
    return suggestionsResult;
  }
}

class FakeDictionarySource implements DictionarySource {
  @override
  final int id;
  final Map<String, String> entries;

  /// Simulates a dictionary that fails to load or read.
  final bool throws;

  /// How many times the dictionary was prefix-searched: the P0-4 cache
  /// tests assert a repeat or longer query does not search again.
  int searchCalls = 0;

  /// Sizes of the batches handed to [resolveKeys]: the P1-13 staged-split
  /// test asserts only the reachable slices were probed.
  final List<int> resolveKeysBatchSizes = [];

  /// Artificial latency for prefix search, for the cancellation test.
  final Duration searchDelay;

  FakeDictionarySource({
    required this.id,
    required this.entries,
    this.throws = false,
    this.searchDelay = Duration.zero,
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
    resolveKeysBatchSizes.add(words.length);
    final resolved = <String, String>{};
    for (final word in words) {
      final key = await resolveExactKey(word);
      if (key != null) resolved[word] = key;
    }
    return resolved;
  }

  @override
  Future<List<String>> search(String query) async {
    searchCalls++;
    await Future.delayed(searchDelay);
    return entries.keys.where((key) => key.startsWith(query)).toList();
  }

  /// The `resolvedKeys` argument of the most recent [readExactEntries]
  /// call, or null when the caller passed none.
  Map<String, String>? lastResolvedKeys;

  /// How many [resolveExactKey] calls the most recent [readExactEntries]
  /// made: candidates covered by `resolvedKeys` must not be resolved again.
  int lastResolveCalls = 0;

  @override
  Future<List<DictionaryEntryData>> readExactEntries(
    Iterable<String> words, {
    Map<String, String>? resolvedKeys,
  }) async {
    lastResolvedKeys = resolvedKeys;
    lastResolveCalls = 0;
    final result = <DictionaryEntryData>[];
    final seen = <String>{};
    for (final word in words) {
      final key = resolvedKeys?[word] ?? await _countedResolve(word);
      if (key != null && seen.add(key)) {
        result.add(DictionaryEntryData(headword: key, content: entries[key]!));
      }
    }
    return result;
  }

  Future<String?> _countedResolve(String word) async {
    lastResolveCalls++;
    return resolveExactKey(word);
  }
}

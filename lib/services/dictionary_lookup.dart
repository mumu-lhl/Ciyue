import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/services/hunspell.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/services/long_vowel_lookup.dart";
import "package:ciyue/services/phrase_lookup.dart";
import "package:ciyue/services/word_split.dart";

/// How many spelling suggestions the "not found" page shows.
///
/// Hunspell can return dozens for a short word; a wall of them is worse than
/// the four or five the user is going to consider anyway.
const _maxSpellingSuggestions = 8;

/// How many phrasal-verb readings of a phrase the "not found" page shows.
const _maxPhraseSuggestions = 3;

/// How many long-vowel readings of a word the "not found" page shows.
///
/// A word with two ambiguous marks — `トーキョー` — offers four readings, and
/// those are all worth seeing because they may be four different entries. A
/// word with more marks than that is not a word anyone typed.
const _maxLongVowelSuggestions = 4;

class DictionaryLookupResult {
  final Map<int, List<DictionaryEntryData>> entriesByDictionary;

  const DictionaryLookupResult({required this.entriesByDictionary});

  List<int> get validDictionaryIds => entriesByDictionary.keys.toList();

  List<DictionaryEntryData> entriesFor(int dictionaryId) {
    return entriesByDictionary[dictionaryId] ?? const [];
  }
}

class DictionarySearchSuggestions {
  final List<String> dictionarySuggestions;
  final List<String> spellingSuggestions;

  const DictionarySearchSuggestions({
    required this.dictionarySuggestions,
    required this.spellingSuggestions,
  });
}

/// Resolves a user query against the active MDX dictionaries.
///
/// This is the seam between the UI and morphology implementations. Callers
/// only need to know about queries and dictionary matches; they do not need to
/// manage Hunspell handles or MDX lookup candidates themselves.
class DictionaryLookup {
  final List<DictionarySource> Function() dictionaries;
  final MorphologyProvider morphology;
  final bool Function() morphologyEnabled;
  final HunspellLookupMode Function() lookupMode;

  const DictionaryLookup({
    required this.dictionaries,
    required this.morphology,
    required this.morphologyEnabled,
    required this.lookupMode,
  });

  Future<DictionaryLookupResult> lookup(String word) async {
    if (word.isEmpty) {
      return const DictionaryLookupResult(entriesByDictionary: {});
    }

    final activeDictionaries = dictionaries();
    if (activeDictionaries.isEmpty) {
      return const DictionaryLookupResult(entriesByDictionary: {});
    }

    // A single broken dictionary must not take down the whole lookup:
    // isolate per-dictionary failures instead of letting Future.wait rethrow.
    final exactKeys = await Future.wait(
      activeDictionaries.map((dict) async {
        try {
          return await dict.resolveExactKey(word);
        } catch (_) {
          return null;
        }
      }),
    );

    final currentMode = lookupMode();
    List<String> stems = const [];
    final shouldResolveStems =
        morphologyEnabled() &&
        (currentMode == HunspellLookupMode.supplement ||
            exactKeys.any((key) => key == null));
    if (shouldResolveStems) {
      stems = await morphology.stems(word);
    }

    final entriesList = await Future.wait(
      List.generate(activeDictionaries.length, (i) async {
        final dict = activeDictionaries[i];
        final exactKey = exactKeys[i];
        final shouldUseStems = switch (currentMode) {
          HunspellLookupMode.fallback => exactKey == null,
          HunspellLookupMode.supplement => true,
        };

        // Every spelling the dictionary might actually store: the exact one
        // first, then its case and kana variants. Reading all of them is what
        // keeps `abend` and `Abend` as two entries instead of silently
        // dropping whichever one the first lookup happened to return.
        final candidates = <String>[...lookupVariants(word)];
        if (shouldResolveStems && shouldUseStems) {
          candidates.addAll(stems);
        }

        // Query all dictionaries concurrently instead of awaiting each
        // disk read + record-block decompression in series.
        // A failing dictionary yields no entries instead of failing lookup.
        try {
          return MapEntry(
            dict.id,
            await dict.readExactEntries({...candidates}),
          );
        } catch (_) {
          return MapEntry(dict.id, const <DictionaryEntryData>[]);
        }
      }),
    );
    final matches = <int, List<DictionaryEntryData>>{
      for (final entry in entriesList)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };

    return DictionaryLookupResult(entriesByDictionary: matches);
  }

  Future<DictionarySearchSuggestions> searchSuggestions(String query) async {
    if (query.isEmpty) {
      return const DictionarySearchSuggestions(
        dictionarySuggestions: [],
        spellingSuggestions: [],
      );
    }

    final activeDictionaries = dictionaries();
    // Skip dictionaries that fail instead of failing the whole suggestion
    // list: a single broken dictionary must not break global search.
    final prefixResults = await Future.wait(
      activeDictionaries.map((dict) async {
        try {
          return await dict.search(query);
        } catch (_) {
          return const <String>[];
        }
      }),
    );
    // `seen` backs O(1) dedup; `results` preserves display order.
    final seen = <String>{
      for (final dictionaryResults in prefixResults) ...dictionaryResults,
    };
    final results = seen.toList()..sort();

    if (!morphologyEnabled()) {
      return DictionarySearchSuggestions(
        dictionarySuggestions: results.toList(growable: false),
        spellingSuggestions: const [],
      );
    }

    final exactKeys = await Future.wait(
      activeDictionaries.map((dict) async {
        try {
          return await dict.resolveExactKey(query);
        } catch (_) {
          return null;
        }
      }),
    );
    final someDictionaryMissed =
        activeDictionaries.isEmpty || exactKeys.any((key) => key == null);
    final stems =
        lookupMode() == HunspellLookupMode.supplement || someDictionaryMissed
        ? await morphology.stems(query)
        : const <String>[];

    // Resolve every stem against every dictionary concurrently, keeping the
    // original first-dictionary-wins order per stem.
    final stemKeyLists = await Future.wait(
      stems.map(
        (stem) => Future.wait(
          activeDictionaries.map((dict) async {
            try {
              return await dict.resolveExactKey(stem);
            } catch (_) {
              return null;
            }
          }),
        ),
      ),
    );
    for (final keys in stemKeyLists) {
      for (final canonicalKey in keys) {
        if (canonicalKey != null) {
          if (seen.add(canonicalKey)) {
            results.add(canonicalKey);
          }
          break;
        }
      }
    }

    final dictionarySuggestions = results.toList(growable: false);
    final spellingSuggestions = <String>[];
    if (someDictionaryMissed) {
      for (final suggestion in await morphology.suggestions(query)) {
        if (seen.add(suggestion)) {
          results.add(suggestion);
          spellingSuggestions.add(suggestion);
        }
      }
    }

    return DictionarySearchSuggestions(
      dictionarySuggestions: dictionarySuggestions,
      spellingSuggestions: spellingSuggestions.toList(growable: false),
    );
  }

  /// Readings of [word] as several known headwords, for the "not found" page.
  ///
  /// A compound or a run of CJK text (`Animecover`, `倾奇者`) is offered
  /// as the headwords it is made of. See [findSplits] for the algorithm and its
  /// limits.
  ///
  /// This is the cheap half of the page's suggestions — a few hundred binary
  /// searches per dictionary, milliseconds in total — and is deliberately
  /// separate from [spellingSuggestionsFor], which costs a hundred times more.
  /// The page draws these first and lets the spelling suggestions arrive later.
  Future<List<WordSplit>> wordSplitsFor(String word) async {
    final query = word.trim();
    if (query.isEmpty) return const [];
    // Splitting is about one word: a phrase would come back as `picked + the +
    // phone + up`, which is true and useless.
    if (query.contains(RegExp(r"\s"))) return const [];

    final activeDictionaries = dictionaries();
    if (activeDictionaries.isEmpty) return const [];

    return _splitsOf(query, activeDictionaries);
  }

  /// Phrasal verbs a phrase might be hiding, for the "not found" page.
  ///
  /// `picked the phone up` is stored as `pick up`; `rufe dich an` as `anrufen`.
  /// Two-word input is not handled here — `picked up` already resolves through
  /// the stems the normal lookup asks for, so only longer phrases arrive.
  ///
  /// Cheap like [wordSplitsFor]: one `stems()` call per word, then a single
  /// probe batch. The readings are filtered by the dictionaries themselves, so
  /// no particle list has to be maintained.
  Future<List<String>> phraseSuggestionsFor(String word) async {
    final tokens = phraseTokens(word);
    if (tokens.length < 3) return const [];

    final activeDictionaries = dictionaries();
    if (activeDictionaries.isEmpty) return const [];

    // Asking for every token's base form in parallel keeps this at the cost of
    // the slowest call rather than their sum.
    final stemsByToken = <String, List<String>>{};
    if (morphologyEnabled()) {
      final stems = await Future.wait(
        tokens.map((token) async {
          try {
            return await morphology.stems(token);
          } catch (_) {
            return const <String>[];
          }
        }),
      );
      for (var i = 0; i < tokens.length; i++) {
        stemsByToken[tokens[i]] = stems[i];
      }
    }

    final candidates = phraseCandidates(
      tokens,
      stemsOf: (token) => stemsByToken[token] ?? const [],
    );
    if (candidates.isEmpty) return const [];

    final resolved = await _resolveAcross(activeDictionaries, candidates);
    final phrases = <String>[];
    for (final candidate in candidates) {
      final spelling = resolved[candidate];
      if (spelling == null || phrases.contains(spelling)) continue;
      phrases.add(spelling);
      if (phrases.length == _maxPhraseSuggestions) break;
    }
    return phrases;
  }

  /// Hiragana readings of a katakana word whose long vowels are marked with
  /// `ー`, for the "not found" page.
  ///
  /// `フーゾク` is filed as ふうぞく and `トーキョー` as とうきょう. Which vowel
  /// the mark stands for cannot be decided from the mark, and a long `e` or `o`
  /// has two spellings each (えい/ええ, おう/おお), so every reading is offered
  /// to the dictionaries and only those that exist come back. See
  /// [longVowelReadings] for the generation.
  ///
  /// Cheap like [wordSplitsFor]: a handful of index probes behind one batch per
  /// dictionary, no morphology, so the page draws it with the splits rather
  /// than after the spelling suggestions.
  Future<List<String>> longVowelSuggestionsFor(String word) async {
    final query = word.trim();
    if (query.isEmpty) return const [];

    final readings = longVowelReadings(query);
    if (readings.isEmpty) return const [];

    final activeDictionaries = dictionaries();
    if (activeDictionaries.isEmpty) return const [];

    final resolved = await _resolveAcross(activeDictionaries, readings);
    final suggestions = <String>[];
    for (final reading in readings) {
      // The dictionary's own spelling: a reading that only matched by script
      // ends up shown the way the entry is filed.
      final spelling = resolved[reading];
      if (spelling == null || suggestions.contains(spelling)) continue;
      suggestions.add(spelling);
      if (suggestions.length == _maxLongVowelSuggestions) break;
    }
    return suggestions;
  }

  /// Hunspell's spelling suggestions for [word], minus everything no dictionary
  /// holds.
  ///
  /// `hunspell_suggest` walks the word list with edit-distance candidates and
  /// is slow: measured at ~330 ms for a 24-character German word, against ~2 ms
  /// for the index probes behind [wordSplitsFor]. Callers show something else
  /// first rather than waiting on this.
  ///
  /// Anything no dictionary can open is dropped: unlike the search bar's list,
  /// a suggestion that lands on another "not found" page is worse than none.
  Future<List<String>> spellingSuggestionsFor(String word) async {
    final query = word.trim();
    if (query.isEmpty) return const [];

    final activeDictionaries = dictionaries();
    if (activeDictionaries.isEmpty) return const [];
    if (!morphologyEnabled()) return const [];

    final List<String> proposed;
    try {
      proposed = await morphology.suggestions(query);
    } catch (_) {
      // A broken word list must not take the page down with it.
      return const [];
    }

    final unique = <String>[];
    for (final suggestion in proposed) {
      final trimmed = suggestion.trim();
      if (trimmed.isEmpty || trimmed == query) continue;
      if (unique.contains(trimmed)) continue;
      unique.add(trimmed);
    }
    if (unique.isEmpty) return const [];

    final resolved = await _resolveAcross(activeDictionaries, unique);
    final suggestions = <String>[];
    for (final suggestion in unique) {
      // `resolved` answers with the dictionary's own spelling, so a query that
      // only matched by case ends up showing what the entry is filed under.
      final spelling = resolved[suggestion];
      if (spelling == null || suggestions.contains(spelling)) continue;
      suggestions.add(spelling);
      if (suggestions.length == _maxSpellingSuggestions) break;
    }
    return suggestions;
  }

  /// Readings of [query] as several known headwords, best first.
  Future<List<WordSplit>> _splitsOf(
    String query,
    List<DictionarySource> activeDictionaries,
  ) async {
    final candidates = splitCandidates(query);
    if (candidates.isEmpty) return const [];

    final resolved = await _resolveAcross(activeDictionaries, candidates);
    if (resolved.isEmpty) return const [];

    return findSplits(query, resolve: (candidate) => resolved[candidate]);
  }

  /// Resolves [words] against every dictionary at once.
  ///
  /// One `await` per dictionary instead of one per word: [splitCandidates]
  /// hands over a few hundred slices for a single query. A dictionary that
  /// throws contributes nothing instead of failing the whole list, and the
  /// first dictionary in group order decides the spelling that is shown.
  Future<Map<String, String>> _resolveAcross(
    List<DictionarySource> activeDictionaries,
    Iterable<String> words,
  ) async {
    final candidates = words.toList(growable: false);
    if (candidates.isEmpty) return const {};

    final resolvedPerDictionary = await Future.wait(
      activeDictionaries.map((dict) async {
        try {
          return await dict.resolveKeys(candidates);
        } catch (_) {
          return const <String, String>{};
        }
      }),
    );

    final resolved = <String, String>{};
    for (final perDictionary in resolvedPerDictionary) {
      for (final entry in perDictionary.entries) {
        resolved.putIfAbsent(entry.key, () => entry.value);
      }
    }
    return resolved;
  }
}

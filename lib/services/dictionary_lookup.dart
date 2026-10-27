import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/services/hunspell.dart";
import "package:ciyue/services/lookup_keys.dart";

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
}

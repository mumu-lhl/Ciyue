import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/services/hunspell.dart";

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

    final exactKeys = await Future.wait(
      activeDictionaries.map((dict) => dict.resolveExactKey(word)),
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

    final matches = <int, List<DictionaryEntryData>>{};
    for (var i = 0; i < activeDictionaries.length; i++) {
      final dict = activeDictionaries[i];
      final exactKey = exactKeys[i];
      final shouldUseStems = switch (currentMode) {
        HunspellLookupMode.fallback => exactKey == null,
        HunspellLookupMode.supplement => true,
      };

      final candidates = <String>[];
      if (exactKey != null) {
        candidates.add(exactKey);
      } else {
        candidates.add(word);
      }
      if (shouldResolveStems && shouldUseStems) {
        candidates.addAll(stems);
      }

      final entries = await dict.readExactEntries({...candidates});
      if (entries.isNotEmpty) {
        matches[dict.id] = entries;
      }
    }

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
    final prefixResults = await Future.wait(
      activeDictionaries.map((dict) => dict.search(query)),
    );
    final results = <String>{
      for (final dictionaryResults in prefixResults) ...dictionaryResults,
    }.toList()..sort();

    if (!morphologyEnabled()) {
      return DictionarySearchSuggestions(
        dictionarySuggestions: results.toList(growable: false),
        spellingSuggestions: const [],
      );
    }

    final exactKeys = await Future.wait(
      activeDictionaries.map((dict) => dict.resolveExactKey(query)),
    );
    final someDictionaryMissed =
        activeDictionaries.isEmpty || exactKeys.any((key) => key == null);
    final stems =
        lookupMode() == HunspellLookupMode.supplement || someDictionaryMissed
        ? await morphology.stems(query)
        : const <String>[];

    for (final stem in stems) {
      for (final dict in activeDictionaries) {
        final canonicalKey = await dict.resolveExactKey(stem);
        if (canonicalKey != null) {
          if (!results.contains(canonicalKey)) {
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
        if (!results.contains(suggestion)) {
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

import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/services/hunspell.dart";

class DictionaryLookupResult {
  final String query;
  final Map<int, List<DictionaryEntryData>> entriesByDictionary;

  const DictionaryLookupResult({
    required this.query,
    required this.entriesByDictionary,
  });

  List<int> get validDictionaryIds => entriesByDictionary.keys.toList();

  bool get hasMatches => entriesByDictionary.isNotEmpty;

  List<DictionaryEntryData> entriesFor(int dictionaryId) {
    return entriesByDictionary[dictionaryId] ?? const [];
  }
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
      return DictionaryLookupResult(query: word, entriesByDictionary: const {});
    }

    final activeDictionaries = dictionaries();
    if (activeDictionaries.isEmpty) {
      return DictionaryLookupResult(query: word, entriesByDictionary: const {});
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

      final entries = await dict.readExactEntries(_dedupe(candidates));
      if (entries.isNotEmpty) {
        matches[dict.id] = entries;
      }
    }

    return DictionaryLookupResult(query: word, entriesByDictionary: matches);
  }

  Future<List<String>> searchSuggestions(String query) async {
    if (query.isEmpty) {
      return const [];
    }

    final activeDictionaries = dictionaries();
    final prefixResults = await Future.wait(
      activeDictionaries.map((dict) => dict.search(query)),
    );
    final prefixResultSet = <String>{};
    for (final dictionaryResults in prefixResults) {
      prefixResultSet.addAll(dictionaryResults);
    }
    final results = prefixResultSet.toList()..sort();

    if (morphologyEnabled()) {
      final stems = await morphology.stems(query);
      if (lookupMode() == HunspellLookupMode.supplement ||
          !await _hasExactMatch(activeDictionaries, query)) {
        for (final stem in stems) {
          final canonicalKey = await _findExactKey(activeDictionaries, stem);
          if (canonicalKey != null && !results.contains(canonicalKey)) {
            results.add(canonicalKey);
          }
        }
      }
    }

    return results.toList(growable: false);
  }

  Future<bool> _hasExactMatch(
    List<DictionarySource> activeDictionaries,
    String word,
  ) async {
    for (final dict in activeDictionaries) {
      if (await dict.resolveExactKey(word) != null) {
        return true;
      }
    }
    return false;
  }

  Future<String?> _findExactKey(
    List<DictionarySource> activeDictionaries,
    String word,
  ) async {
    for (final dict in activeDictionaries) {
      final key = await dict.resolveExactKey(word);
      if (key != null) {
        return key;
      }
    }
    return null;
  }

  Iterable<String> _dedupe(Iterable<String> words) {
    return {...words};
  }
}

import "dart:collection";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/models/search_mode.dart";
import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search_service.dart";
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

/// How long a Hunspell call may hold up a suggestion list.
///
/// `suggest` is slow — measured at ~330 ms for a 24-character German word —
/// and it is only a supplement: the dictionary results are already in hand
/// when it runs. Past this bound the call degrades to "no stems/suggestions"
/// instead of stalling the list. The timeout only ever touches the Hunspell
/// branches; a dictionary that found nothing still reports exactly that.
const _morphologyTimeout = Duration(milliseconds: 300);

/// Most prefix-suggestion queries kept in the cache (see [_prefixCache]).
const _maxPrefixCacheEntries = 64;

/// Per-dictionary cap on prefix matches (`reader.search` defaults to 30).
///
/// The incremental cache filter is only used when the cached prefix result
/// holds fewer entries than this: with fewer than 30 merged results no
/// dictionary could have hit its cap, so the cached set is the complete
/// prefix set and filtering it cannot lose a match.
const _prefixSearchLimit = 30;

/// One cached prefix-suggestion answer.
///
/// [prefixResults] is kept apart from [dictionarySuggestions] because only
/// the prefix part is a subset of the previous keystroke's prefix part:
/// stem-resolved keys appended to the suggestions need not start with the
/// query at all (`went` -> `go`), so they must be resolved again instead of
/// filtered.
class _PrefixCacheEntry {
  final List<String> prefixResults;
  final List<String> dictionarySuggestions;
  final List<String> spellingSuggestions;

  const _PrefixCacheEntry({
    required this.prefixResults,
    required this.dictionarySuggestions,
    required this.spellingSuggestions,
  });
}

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

  /// Full-text definition hits, only filled in [SearchMode.fullText]:
  /// the other modes surface headwords through [dictionarySuggestions].
  final List<FullTextHit> fullTextHits;

  /// Worst full-text index status across the active dictionaries. Only
  /// meaningful for the modes that need the index ([SearchMode.suffix],
  /// [SearchMode.multiWord], [SearchMode.fullText]); prefix mode leaves
  /// it at [FullTextIndexStatus.ready].
  final FullTextIndexStatus fullTextIndexStatus;

  const DictionarySearchSuggestions({
    required this.dictionarySuggestions,
    required this.spellingSuggestions,
    this.fullTextHits = const [],
    this.fullTextIndexStatus = FullTextIndexStatus.ready,
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

  /// Monotonic id for prefix-suggestion runs. A newer keystroke bumps it;
  /// every `await` in [_prefixSuggestions] checks it and bails out with the
  /// prefix results already in hand instead of doing the rest of the
  /// pipeline for a query the user has already moved past.
  int _prefixGen = 0;

  /// Prefix-suggestion answers by query, for the current dictionary set.
  ///
  /// Keyed by query only; [_prefixCacheFingerprint] tracks which dictionary
  /// set (and morphology settings) the entries belong to, and a change
  /// clears the cache. An exact hit answers with zero I/O; a longer query
  /// whose cached shorter prefix holds fewer than [_prefixSearchLimit]
  /// results is filtered from that set instead of searched.
  final Map<String, _PrefixCacheEntry> _prefixCache = {};
  String? _prefixCacheFingerprint;

  DictionaryLookup({
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
      try {
        stems = await morphology.stems(word);
      } catch (e) {
        // Morphology is an optional aid. A worker that failed to load must not
        // turn the exact lookup into an error page.
        talker.warning("Hunspell stems failed for \"$word\": $e");
      }
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
            await dict.readExactEntries(
              {...candidates},
              // The exact key was already resolved above; hand it over so
              // the read does not resolve the query spelling a second time.
              resolvedKeys: exactKey == null ? null : {word: exactKey},
            ),
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

  /// Suggestions for [query] under [mode].
  ///
  /// Prefix mode is the historical behaviour: headword-prefix matches plus
  /// morphology stems and spelling suggestions. The other modes are served
  /// by the full-text index through [fullText]: suffix and multi-word AND
  /// return matching headwords as [DictionarySearchSuggestions
  /// .dictionarySuggestions], full-text mode returns definition hits in
  /// [DictionarySearchSuggestions.fullTextHits]. When [fullText] is null
  /// (or no index is ready) those modes report
  /// [FullTextIndexStatus.notBuilt] instead of an unexplained empty list,
  /// so the UI can say why there is nothing to show.
  ///
  /// Exact lookup on submit is deliberately NOT mode-dependent: Enter
  /// always opens the exact headword, in every mode.
  Future<DictionarySearchSuggestions> searchSuggestions(
    String query, {
    SearchMode mode = SearchMode.prefix,
    FullTextSearchService? fullText,
  }) async {
    if (query.isEmpty) {
      return const DictionarySearchSuggestions(
        dictionarySuggestions: [],
        spellingSuggestions: [],
      );
    }

    if (mode != SearchMode.prefix) {
      return _fullTextSuggestions(query, mode, fullText);
    }

    return _prefixSuggestions(query);
  }

  Future<DictionarySearchSuggestions> _fullTextSuggestions(
    String query,
    SearchMode mode,
    FullTextSearchService? fullText,
  ) async {
    if (fullText == null) {
      return const DictionarySearchSuggestions(
        dictionarySuggestions: [],
        spellingSuggestions: [],
        fullTextIndexStatus: FullTextIndexStatus.notBuilt,
      );
    }
    // Same width handling as the prefix path: a full-width query must
    // still reach its half-width headwords.
    final hits = <FullTextHit>[];
    final seenHeadwords = <String>{};
    for (final variant in widthVariants(query)) {
      final variantHits = switch (mode) {
        SearchMode.suffix => await fullText.searchSuffix(variant),
        SearchMode.multiWord => await fullText.searchHeadwordAnd(variant),
        SearchMode.fullText => await fullText.search(variant),
        SearchMode.prefix => const <FullTextHit>[],
      };
      for (final hit in variantHits) {
        if (seenHeadwords.add(hit.headword)) hits.add(hit);
      }
    }
    final status = await fullText.indexStatus();
    if (mode == SearchMode.fullText) {
      return DictionarySearchSuggestions(
        dictionarySuggestions: const [],
        spellingSuggestions: const [],
        fullTextHits: hits,
        fullTextIndexStatus: status,
      );
    }
    return DictionarySearchSuggestions(
      dictionarySuggestions: [for (final hit in hits) hit.headword],
      spellingSuggestions: const [],
      fullTextIndexStatus: status,
    );
  }

  void _cachePrefixResult(
    String query,
    List<String> prefixResults,
    List<String> dictionarySuggestions,
    List<String> spellingSuggestions,
  ) {
    if (_prefixCache.length >= _maxPrefixCacheEntries) {
      _prefixCache.remove(_prefixCache.keys.first);
    }
    _prefixCache[query] = _PrefixCacheEntry(
      prefixResults: prefixResults,
      dictionarySuggestions: dictionarySuggestions,
      spellingSuggestions: spellingSuggestions,
    );
  }

  DictionarySearchSuggestions _prefixOnlyResult(List<String> results) {
    return DictionarySearchSuggestions(
      dictionarySuggestions: results.toList(growable: false),
      spellingSuggestions: const [],
    );
  }

  Future<DictionarySearchSuggestions> _prefixSuggestions(String query) async {
    // A newer keystroke cancels this run: bump first, so even a cache hit
    // abandons the in-flight pipeline for the older query.
    final gen = ++_prefixGen;
    bool isCancelled() => gen != _prefixGen;

    final activeDictionaries = dictionaries();
    final fingerprint = _suggestionFingerprint(
      activeDictionaries,
      morphologyEnabled(),
      lookupMode(),
    );
    if (fingerprint != _prefixCacheFingerprint) {
      // The dictionary set (or morphology setting) changed: cached answers
      // belong to dictionaries that may no longer be loaded.
      _prefixCache.clear();
      _prefixCacheFingerprint = fingerprint;
    }

    final cached = _prefixCache[query];
    if (cached != null) {
      return DictionarySearchSuggestions(
        dictionarySuggestions: cached.dictionarySuggestions,
        spellingSuggestions: cached.spellingSuggestions,
      );
    }

    // Incremental filter: the prefix matches of a longer query are a subset
    // of the shorter query's — but only when the shorter answer was not
    // truncated by the per-dictionary cap (see [_prefixSearchLimit]).
    List<String>? prefixResults;
    final queryVariants = widthVariants(query);
    final queryPrefixes = [
      for (final variant in queryVariants) variant.toLowerCase(),
    ];
    String? incrementalQuery;
    for (final entry in _prefixCache.entries) {
      if (entry.key.length >= query.length ||
          !query.startsWith(entry.key) ||
          entry.value.prefixResults.length >= _prefixSearchLimit) {
        continue;
      }
      if (incrementalQuery == null ||
          entry.key.length > incrementalQuery.length) {
        incrementalQuery = entry.key;
      }
    }
    final incrementalEntry = incrementalQuery == null
        ? null
        : _prefixCache[incrementalQuery];
    if (incrementalEntry != null) {
      prefixResults = [
        for (final headword in incrementalEntry.prefixResults)
          if (queryPrefixes.any(
            (prefix) =>
                headword.toLowerCase().startsWith(prefix) ||
                headword.startsWith(query) ||
                queryVariants.any(headword.startsWith),
          ))
            headword,
      ];
    }

    // Skip dictionaries that fail instead of failing the whole suggestion
    // list: a single broken dictionary must not break global search.
    //
    // Search takes the query as typed: a full-width query (`ＮＨ`) must still
    // suggest a half-width headword (`NHK`), so every width spelling is tried.
    // `search` already folds case, so the case variants are not needed here.
    // A query with no width change asks each dictionary once.
    prefixResults ??= await _searchPrefixAcross(
      activeDictionaries,
      queryVariants,
    );
    // `seen` backs O(1) dedup; `results` preserves display order.
    final seen = <String>{...prefixResults};
    final results = seen.toList()..sort();
    // Snapshot before the stem stage appends to `results`: the cache's
    // prefix part is exactly this list, not the stem-resolved tail.
    final prefixSnapshot = results.toList(growable: false);
    if (isCancelled()) {
      // Stale keystroke: the prefix matches are complete and valid for this
      // query, so hand them back instead of doing the Hunspell stages for
      // a query nobody is looking at any more. The caller drops them anyway
      // when it has a newer query.
      return _prefixOnlyResult(results);
    }

    if (!morphologyEnabled()) {
      _cachePrefixResult(query, prefixSnapshot, prefixSnapshot, const []);
      return _prefixOnlyResult(results);
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
    if (isCancelled()) return _prefixOnlyResult(results);
    final someDictionaryMissed =
        activeDictionaries.isEmpty || exactKeys.any((key) => key == null);
    final stems =
        lookupMode() == HunspellLookupMode.supplement || someDictionaryMissed
        ? await _morphologyWithTimeout(() => morphology.stems(query))
        : const <String>[];
    if (isCancelled()) return _prefixOnlyResult(results);

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
    if (isCancelled()) return _prefixOnlyResult(results);
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
      for (final suggestion in await _morphologyWithTimeout(
        () => morphology.suggestions(query),
      )) {
        if (seen.add(suggestion)) {
          results.add(suggestion);
          spellingSuggestions.add(suggestion);
        }
      }
    }
    if (isCancelled()) {
      // The dictionary part is complete; only the spelling tail may be
      // partial, so it is left out rather than cached as if complete.
      return DictionarySearchSuggestions(
        dictionarySuggestions: dictionarySuggestions,
        spellingSuggestions: const [],
      );
    }

    final result = DictionarySearchSuggestions(
      dictionarySuggestions: dictionarySuggestions,
      spellingSuggestions: spellingSuggestions.toList(growable: false),
    );
    _cachePrefixResult(
      query,
      prefixSnapshot,
      dictionarySuggestions,
      result.spellingSuggestions,
    );
    return result;
  }

  /// Runs a Hunspell call with a [_morphologyTimeout] bound, degrading to
  /// empty on timeout or failure.
  ///
  /// Hunspell is a supplement to the dictionary results, never the lookup
  /// itself: a slow or broken worker must not stall the list, and a timeout
  /// here says nothing about whether any dictionary matched.
  Future<List<String>> _morphologyWithTimeout(
    Future<List<String>> Function() call,
  ) async {
    try {
      return await call().timeout(
        _morphologyTimeout,
        onTimeout: () => const <String>[],
      );
    } catch (e) {
      talker.warning("Hunspell call failed: $e");
      return const <String>[];
    }
  }

  /// Cache key for the current suggestion inputs: which dictionaries (by
  /// instance, so a re-enabled dictionary with a new instance invalidates),
  /// and the morphology settings the answer depends on.
  String _suggestionFingerprint(
    List<DictionarySource> activeDictionaries,
    bool morphology,
    HunspellLookupMode mode,
  ) {
    final buffer = StringBuffer()
      ..write(morphology ? "m1" : "m0")
      ..write(mode);
    for (final dict in activeDictionaries) {
      buffer
        ..write(",")
        ..write(dict.id)
        ..write(":")
        ..write(identityHashCode(dict));
    }
    return buffer.toString();
  }

  Future<List<String>> _searchPrefixAcross(
    List<DictionarySource> activeDictionaries,
    List<String> queryVariants,
  ) async {
    final prefixResults = await Future.wait(
      activeDictionaries.map((dict) async {
        final matches = <String>{};
        for (final variant in queryVariants) {
          try {
            matches.addAll(await dict.search(variant));
          } catch (_) {
            // A broken dictionary contributes nothing instead of failing.
          }
        }
        return matches.toList(growable: false);
      }),
    );
    return [
      for (final dictionaryResults in prefixResults) ...dictionaryResults,
    ];
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
  /// `picked the phone up` is stored as `pick up`; `sehe an` as `ansehen`.
  /// Two-word input is in scope: the normal stems lookup keeps the space
  /// (`sehen an`), so only this pass can join the halves the way a German
  /// dictionary files them. English `picked up` usually resolves before this
  /// page is shown, and is one more harmless candidate when it does not.
  ///
  /// Cheap like [wordSplitsFor]: one `stems()` call per word, then a single
  /// probe batch. The readings are filtered by the dictionaries themselves, so
  /// no particle list has to be maintained.
  Future<List<String>> phraseSuggestionsFor(String word) async {
    final tokens = phraseTokens(word);
    // The same bounds as [phraseCandidates], before the stems calls, so a
    // pasted paragraph costs nothing.
    if (tokens.length < minPhraseWords || tokens.length > maxPhraseWords) {
      return const [];
    }

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
      // Same bound as the search bar's Hunspell calls: a slow `suggest`
      // degrades to no spelling suggestions instead of holding the page.
      proposed = await _morphologyWithTimeout(
        () => morphology.suggestions(query),
      );
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
  ///
  /// The candidates are probed in stages, not all at once: the first stage
  /// probes only the slices starting at position 0, and each later stage
  /// probes only the slices starting where a resolved part ends (or after a
  /// linking morpheme there — see [splitStartPositions]). Slices starting
  /// at a position no part can reach are never probed: for a long compound
  /// that is most of the O(n²) set. The result is the same as probing all
  /// of them, because [findSplits] only ever asks about slices starting at
  /// exactly those positions.
  Future<List<WordSplit>> _splitsOf(
    String query,
    List<DictionarySource> activeDictionaries,
  ) async {
    final byStart = splitCandidatesByStart(query);
    if (byStart.isEmpty) return const [];

    final resolved = <String, String>{};
    final probed = <String>{};
    var reachable = <int>{0};
    while (true) {
      final pending = <String>{};
      final pendingStarts = <String, Set<int>>{};
      for (final start in reachable) {
        final slices = byStart[start];
        if (slices == null) continue;
        for (final slice in slices) {
          if (probed.contains(slice)) continue;
          pending.add(slice);
          (pendingStarts[slice] ??= <int>{}).add(start);
        }
      }
      if (pending.isEmpty) break;
      probed.addAll(pending);

      final batch = await _resolveAcross(activeDictionaries, pending);
      resolved.addAll(batch);
      if (batch.isEmpty) break;

      final partEnds = <int>{
        for (final entry in batch.entries)
          for (final start in pendingStarts[entry.key] ?? const <int>{})
            start + entry.key.length,
      };
      final grown = splitStartPositions(query, partEnds);
      final before = reachable.length;
      reachable = {...reachable, ...grown};
      if (reachable.length == before) break;
    }
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
    // A repeated slice (the same substring at several positions of a
    // compound) is probed once: [resolveKeys] rebuilds the spelling variants
    // of every word it is handed, even a duplicate.
    final candidates = LinkedHashSet<String>.of(words).toList(growable: false);
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

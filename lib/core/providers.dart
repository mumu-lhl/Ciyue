import "dart:async";
import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/open_records.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/services/dictionary_lookup_instance.dart";
import "package:ciyue/services/full_text_search_service.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/viewModels/selection_text_view_model.dart";
import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:ciyue/viewModels/ai_explanation.dart";
import "package:ciyue/viewModels/ai_settings_view_model.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:ciyue/viewModels/writing_check.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_riverpod/legacy.dart";

final settingsProvider = ChangeNotifierProvider((ref) => settings);

final homeModelProvider = ChangeNotifierProvider<HomeModel>(
  (ref) => HomeModel(),
);

final dictManagerModelProvider = ChangeNotifierProvider<DictManagerModel>(
  (ref) => DictManagerModel(
    onDictionariesChanged: () =>
        ref.read(dictSetVersionProvider.notifier).bump(),
  ),
);

final historyModelProvider = ChangeNotifierProvider<HistoryModel>(
  (ref) => HistoryModel(),
);

final wordbookModelProvider = ChangeNotifierProvider<WordbookModel>(
  (ref) => WordbookModel(),
);

final audioModelProvider = ChangeNotifierProvider<AudioModel>(
  (ref) => AudioModel()..init(),
);

final manageDictionariesModelProvider =
    ChangeNotifierProvider<ManageDictionariesModel>(
      (ref) => ManageDictionariesModel(),
    );

final aiPromptsProvider = ChangeNotifierProvider<AIPrompts>(
  (ref) => AIPrompts(),
);

final selectionTextViewModelProvider =
    ChangeNotifierProvider<SelectionTextViewModel>(
      (ref) => SelectionTextViewModel(),
    );

final openRecordsRepositoryProvider = Provider<OpenRecordsRepository>(
  (ref) => OpenRecordsRepository(),
);

final writingCheckHistoryDaoProvider = Provider<WritingCheckHistoryDao>(
  (ref) => WritingCheckHistoryDao(mainDatabase),
);

final translateHistoryDaoProvider = Provider<TranslateHistoryDao>(
  (ref) => TranslateHistoryDao(mainDatabase),
);

final aboutViewModelProvider = Provider<AboutViewModel>(
  (ref) => AboutViewModel(),
);

final aiSettingsViewModelProvider =
    ChangeNotifierProvider.autoDispose<AISettingsViewModel>((ref) {
      final aiPrompts = ref.watch(aiPromptsProvider);
      final homeModel = ref.watch(homeModelProvider);
      return AISettingsViewModel(aiPrompts, homeModel);
    });

class DictionaryDarkReaderNotifier extends Notifier<bool> {
  @override
  bool build() => settings.dictionaryDarkReaderEnabled;

  Future<void> setEnabled(bool value) async {
    await settings.setDictionaryDarkReaderEnabled(value);
    state = value;
  }
}

final dictionaryDarkReaderProvider =
    NotifierProvider<DictionaryDarkReaderNotifier, bool>(
      DictionaryDarkReaderNotifier.new,
    );

final dictManagerProvider = Provider((ref) => dictManager);

/// Full-text search over dictionary definitions: lazy per-dictionary FTS5
/// indexes plus the merged search across the active group.
final fullTextSearchServiceProvider =
    ChangeNotifierProvider<FullTextSearchService>((ref) {
      return FullTextSearchService(
        dictionaries: () =>
            [for (final id in dictManager.dictIds) dictManager.dicts[id]]
                .whereType<DictionarySource>()
                .toList(growable: false),
        knownIds: () async =>
            (await dictionaryListDao.all()).map((d) => d.id).toSet(),
      );
    });

/// Resolves a word once so the preview and its dictionary tabs use the same
/// set of exact and morphology matches.
///
/// autoDispose: bounds memory (no unbounded per-word cache). The wait for
/// dictionary loading is bounded too: without a timeout a stuck init would
/// hang this future (and its polling timer) forever, even after dispose.
/// Waits until the dictionaries of the current group finished loading.
///
/// A group switch registers the dictionaries with their metadata first and
/// loads their entries in the background. A lookup that runs before that
/// finishes matches nothing, and the empty result would be cached for the
/// whole keep-alive window — that is what left the first tab blank after
/// switching back. Wait (bounded) for the entries instead.
Future<void> _waitForDictionaries() async {
  // When nothing is loaded there is nothing to wait for. The manager starts in
  // its `isLoading == true` state and only clears it after initialization, so
  // without this guard the poll below would spin forever (e.g. in tests that
  // never run initApp, leaving a pending timer at teardown).
  if (dictManager.dicts.isEmpty) return;

  talker.info(
    "waitForDictionaries start: ids=${dictManager.dicts.keys.toList()} "
    "isLoading=${dictManager.isLoading}",
  );
  var waited = 0;
  while (dictManager.isLoading && waited < 200) {
    await Future.delayed(const Duration(milliseconds: 50));
    waited++;
  }

  await Future.wait(
    dictManager.dicts.values.map(
      (dict) => dict
          .waitForLoading()
          .timeout(const Duration(seconds: 10), onTimeout: () {})
          .catchError((Object _) {}),
    ),
  );
  talker.info("waitForDictionaries done: polled=${waited * 50}ms");
}

final dictionaryLookupProvider = FutureProvider.autoDispose
    .family<DictionaryLookupResult, String>((ref, word) async {
      // The group may have switched, which changes the dictionaries the word
      // is looked up in. The cached result of the old group is worthless.
      ref.watch(dictSetVersionProvider);
      await _waitForDictionaries();

      return dictionaryLookup.lookup(word);
    });

/// FutureProvider that fetches the HTML content of a word for a specific
/// dictionary. Multiple matching headwords are rendered in one dictionary
/// panel so the existing tab/expansion layout does not change.
///
/// Auto-dispose with a 5-minute keep-alive: bounds memory (no unbounded
/// per-(word, dictId) cache) while avoiding refetch when switching tabs.
final wordContentProvider = FutureProvider.autoDispose
    .family<String, ({String word, int dictId})>((ref, params) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 5), link.close);
      ref.onDispose(timer.cancel);

      // Watching the version above the early return matters: a dictionary that
      // leaves the group and is enabled again keeps the same id but gets a new
      // instance (a new local server port for ZIM), and the empty entry cached
      // by the branch below would otherwise outlive the keep-alive window and
      // leave the re-enabled tab blank. Subscribing here also means the lookup
      // is redone as soon as the set changes, not when the next word is typed.
      ref.watch(dictSetVersionProvider);

      var dict = dictManager.dicts[params.dictId];
      if (dict == null) {
        // A group switch clears the dictionaries before reloading them, and
        // this provider can run while that is in flight. Wait for the switch
        // instead of caching an empty entry for the whole keep-alive window —
        // that is what left the first tab blank after switching back.
        await dictManager.waitForGroupSwitch();
        var waited = 0;
        while (dictManager.isLoading && waited < 200) {
          await Future.delayed(const Duration(milliseconds: 50));
          waited++;
        }
        dict = dictManager.dicts[params.dictId];
        if (dict == null) {
          // Never keep a blank entry alive; see above.
          link.close();
          return "";
        }
      }

      final lookup = await ref.watch(
        dictionaryLookupProvider(params.word).future,
      );
      final entries = lookup.entriesFor(params.dictId);
      if (entries.isEmpty) {
        // Never keep an empty entry alive: a group switch can look this up
        // before the dictionaries finished loading, and the blank content
        // would otherwise stick for the whole keep-alive window.
        link.close();
        return "";
      }

      if (entries.length == 1) {
        return dict.wrapContentWithResources(entries.single.content);
      }

      final html = entries
          .map(
            (entry) =>
                "<section class=\"ciyue-hunspell-entry\">"
                "<h2>${const HtmlEscape().convert(entry.headword)}</h2>"
                "${entry.content}</section>",
          )
          .join();
      return dict.wrapContentWithResources(html);
    });

/// FutureProvider that returns dictionary IDs with at least one exact or
/// morphology-resolved entry for the given word.
final validDictIdsProvider = FutureProvider.autoDispose
    .family<List<int>, String>((ref, word) async {
      if (word.isEmpty) return [];
      final lookup = await ref.watch(dictionaryLookupProvider(word).future);
      return lookup.validDictionaryIds;
    });

/// Readings of a word as several headwords, for the "not found" page.
///
/// Milliseconds of index probing, so the page draws these first. Dropped when
/// the page goes away, so revisiting the same word does not probe again.
final wordSplitsProvider = FutureProvider.autoDispose
    .family<List<WordSplit>, String>((ref, word) async {
      // A split is only offered when a dictionary of the current group holds
      // the pieces, so switching the group changes the answer.
      ref.watch(dictSetVersionProvider);
      await _waitForDictionaries();
      return dictionaryLookup.wordSplitsFor(word);
    });

/// Phrasal verbs a phrase may be hiding, for the "not found" page.
///
/// Also fast — one `stems()` call per word — so it is drawn with the splits
/// rather than after them.
final phraseSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, word) async {
      // The readings are filtered by the dictionaries of the current group.
      ref.watch(dictSetVersionProvider);
      await _waitForDictionaries();
      return dictionaryLookup.phraseSuggestionsFor(word);
    });

/// Hiragana readings of a katakana word's long vowels, for the "not found"
/// page.
///
/// Also fast — a handful of index probes — so it is drawn with the splits
/// rather than after the spelling suggestions.
final longVowelSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, word) async {
      // The readings are only offered when a dictionary of the current group
      // holds them.
      ref.watch(dictSetVersionProvider);
      await _waitForDictionaries();
      return dictionaryLookup.longVowelSuggestionsFor(word);
    });

/// Hunspell's spelling corrections for a word no dictionary matched.
///
/// Deliberately separate from [wordSplitsProvider]: `suggest` takes hundreds of
/// milliseconds, and waiting for it would hold back the splits that are ready
/// almost immediately.
final missingWordSpellingSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, word) async {
      // Hunspell's corrections are dropped when no dictionary of the current
      // group can open them.
      ref.watch(dictSetVersionProvider);
      await _waitForDictionaries();
      return dictionaryLookup.spellingSuggestionsFor(word);
    });

class WebViewHeightsNotifier extends Notifier<Map<String, double>> {
  /// Max cached heights. Prevents unbounded memory growth as the user
  /// looks up more words.
  static const _maxEntries = 200;

  @override
  Map<String, double> build() => {};

  void setHeight(String word, int dictId, double height) {
    final key = "$word:$dictId";
    // Skip notifying when the height didn't change: every notification
    // rebuilds all WebViews that watch the heights map.
    if (state[key] == height) return;
    var newState = {...state, key: height};
    // Evict oldest entries when over capacity (Map preserves insertion order).
    if (newState.length > _maxEntries) {
      final keysToRemove = newState.keys.take(newState.length - _maxEntries);
      newState = Map.fromEntries(
        newState.entries.where((e) => !keysToRemove.contains(e.key)),
      );
      // Ensure the just-set key survives eviction.
      newState[key] = height;
    }
    state = newState;
  }

  /// Clear cached heights, e.g. when dictionaries change.
  void clear() {
    state = {};
  }
}

final webviewHeightsProvider =
    NotifierProvider<WebViewHeightsNotifier, Map<String, double>>(
      WebViewHeightsNotifier.new,
    );

/// Counts how often the set of dictionaries to look up in changed.
///
/// A lookup is cached per word, so the group switching has to be announced:
/// without it the words on screen keep the dictionaries of the group they
/// were looked up in.
class DictSetVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dictSetVersionProvider = NotifierProvider<DictSetVersionNotifier, int>(
  DictSetVersionNotifier.new,
);

final writingCheckViewModelProvider =
    ChangeNotifierProvider.autoDispose<WritingCheckViewModel>((ref) {
      return WritingCheckViewModel(
        aiPrompts: ref.read(aiPromptsProvider),
        historyDao: ref.read(writingCheckHistoryDaoProvider),
      );
    });

/// AIExplanationModel family provider per word.
final aiExplanationModelProvider = ChangeNotifierProvider.family
    .autoDispose<AIExplanationModel, String>((ref, word) {
      return AIExplanationModel(aiPrompts: ref.read(aiPromptsProvider));
    });

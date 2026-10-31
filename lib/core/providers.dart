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

/// Provider for global settings.
final settingsProvider = ChangeNotifierProvider((ref) => settings);

/// HomeModel provider.
final homeModelProvider = ChangeNotifierProvider<HomeModel>(
  (ref) => HomeModel(),
);

/// DictManagerModel provider.
final dictManagerModelProvider = ChangeNotifierProvider<DictManagerModel>(
  (ref) => DictManagerModel(),
);

/// HistoryModel provider.
final historyModelProvider = ChangeNotifierProvider<HistoryModel>(
  (ref) => HistoryModel(),
);

/// WordbookModel provider.
final wordbookModelProvider = ChangeNotifierProvider<WordbookModel>(
  (ref) => WordbookModel(),
);

/// AudioModel provider.
final audioModelProvider = ChangeNotifierProvider<AudioModel>(
  (ref) => AudioModel()..init(),
);

/// ManageDictionariesModel provider.
final manageDictionariesModelProvider =
    ChangeNotifierProvider<ManageDictionariesModel>(
      (ref) => ManageDictionariesModel(),
    );

/// AIPrompts provider.
final aiPromptsProvider = ChangeNotifierProvider<AIPrompts>(
  (ref) => AIPrompts(),
);

/// SelectionTextViewModel provider.
final selectionTextViewModelProvider =
    ChangeNotifierProvider<SelectionTextViewModel>(
      (ref) => SelectionTextViewModel(),
    );

/// OpenRecordsRepository provider.
final openRecordsRepositoryProvider = Provider<OpenRecordsRepository>(
  (ref) => OpenRecordsRepository(),
);

/// WritingCheckHistoryDao provider.
final writingCheckHistoryDaoProvider = Provider<WritingCheckHistoryDao>(
  (ref) => WritingCheckHistoryDao(mainDatabase),
);

/// TranslateHistoryDao provider.
final translateHistoryDaoProvider = Provider<TranslateHistoryDao>(
  (ref) => TranslateHistoryDao(mainDatabase),
);

/// AboutViewModel provider.
final aboutViewModelProvider = Provider<AboutViewModel>(
  (ref) => AboutViewModel(),
);

/// AISettingsViewModel provider.
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

/// Provider for the dictionary manager.
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
final dictionaryLookupProvider = FutureProvider.autoDispose
    .family<DictionaryLookupResult, String>((ref, word) async {
      var waited = 0;
      while (dictManager.isLoading && waited < 200) {
        await Future.delayed(const Duration(milliseconds: 50));
        waited++;
      }

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

      final dict = dictManager.dicts[params.dictId];
      if (dict == null) return "";

      final lookup = await ref.watch(
        dictionaryLookupProvider(params.word).future,
      );
      final entries = lookup.entriesFor(params.dictId);
      if (entries.isEmpty) return "";

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
      return dictionaryLookup.wordSplitsFor(word);
    });

/// Phrasal verbs a phrase may be hiding, for the "not found" page.
///
/// Also fast — one `stems()` call per word — so it is drawn with the splits
/// rather than after them.
final phraseSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, word) async {
      return dictionaryLookup.phraseSuggestionsFor(word);
    });

/// Hiragana readings of a katakana word's long vowels, for the "not found"
/// page.
///
/// Also fast — a handful of index probes — so it is drawn with the splits
/// rather than after the spelling suggestions.
final longVowelSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, word) async {
      return dictionaryLookup.longVowelSuggestionsFor(word);
    });

/// Hunspell's spelling corrections for a word no dictionary matched.
///
/// Deliberately separate from [wordSplitsProvider]: `suggest` takes hundreds of
/// milliseconds, and waiting for it would hold back the splits that are ready
/// almost immediately.
final missingWordSpellingSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, word) async {
      return dictionaryLookup.spellingSuggestionsFor(word);
    });

/// Notifier for managing the heights of multiple WebViews.
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

/// Provider for managing WebView heights.
final webviewHeightsProvider =
    NotifierProvider<WebViewHeightsNotifier, Map<String, double>>(
      WebViewHeightsNotifier.new,
    );

/// WritingCheckViewModel provider.
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

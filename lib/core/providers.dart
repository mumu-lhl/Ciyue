import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/open_records.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/services/dictionary_lookup_instance.dart";
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
final settingsProvider = Provider((ref) => settings);

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

/// Resolves a word once so the preview and its dictionary tabs use the same
/// set of exact and morphology matches.
final dictionaryLookupProvider =
    FutureProvider.family<DictionaryLookupResult, String>((ref, word) async {
      while (dictManager.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      return dictionaryLookup.lookup(word);
    });

/// FutureProvider that fetches the HTML content of a word for a specific
/// dictionary. Multiple matching headwords are rendered in one dictionary
/// panel so the existing tab/expansion layout does not change.
final wordContentProvider =
    FutureProvider.family<String, ({String word, int dictId})>((
      ref,
      params,
    ) async {
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
final validDictIdsProvider = FutureProvider.family<List<int>, String>((
  ref,
  word,
) async {
  if (word.isEmpty) return [];
  final lookup = await ref.watch(dictionaryLookupProvider(word).future);
  return lookup.validDictionaryIds;
});

/// Notifier for managing the heights of multiple WebViews.
class WebViewHeightsNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => {};

  void setHeight(String word, int dictId, double height) {
    state = {...state, "$word:$dictId": height};
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

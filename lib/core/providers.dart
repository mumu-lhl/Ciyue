import "dart:convert";

import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/services/dictionary_lookup_instance.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Provider for global settings.
final settingsProvider = Provider((ref) => settings);

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
class WebViewHeightsNotifier extends Notifier<Map<int, double>> {
  @override
  Map<int, double> build() => {};

  void setHeight(int dictId, double height) {
    state = {...state, dictId: height};
  }
}

/// Provider for managing WebView heights.
final webviewHeightsProvider =
    NotifierProvider<WebViewHeightsNotifier, Map<int, double>>(
      WebViewHeightsNotifier.new,
    );

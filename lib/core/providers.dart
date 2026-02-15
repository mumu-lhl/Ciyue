import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Provider for global settings.
final settingsProvider = Provider((ref) => settings);

/// Provider for the dictionary manager.
final dictManagerProvider = Provider((ref) => dictManager);

/// FutureProvider that fetches the HTML content of a word for a specific dictionary.
/// This automates the word-reading logic and handles loading states.
final wordContentProvider =
    FutureProvider.family<String, ({String word, int dictId})>(
        (ref, params) async {
  final dict = dictManager.dicts[params.dictId];
  if (dict == null) return "";
  return await dict.readWord(params.word);
});

/// FutureProvider that returns a list of dictionary IDs that contain the given word.
/// This replaces the manual async loop logic previously found in [WordDisplay].
final validDictIdsProvider =
    FutureProvider.family<List<int>, String>((ref, word) async {
  // Wait until the dictionary manager has finished loading.
  while (dictManager.isLoading) {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  if (word.isEmpty) return [];

  final validIds = <int>[];
  for (final id in dictManager.dictIds) {
    final dict = dictManager.dicts[id];
    if (dict != null && await dict.wordExist(word)) {
      validIds.add(id);
    }
  }
  return validIds;
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
        WebViewHeightsNotifier.new);

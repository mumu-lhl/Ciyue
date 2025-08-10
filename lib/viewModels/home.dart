import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/viewModels/history_view_model.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class HistoryModel extends HistoryViewModel<HistoryData> {
  bool get enableHistory => settings.enableHistory;

  void addHistory(String word) async {
    if (!settings.enableHistory) {
      return;
    }
    await historyDao.addHistory(word);
    await loadHistory();
  }

  void clearHistory() async {
    await historyDao.clearHistory();
    await loadHistory();
  }

  @override
  Future<void> deleteHistory(int id) async {
    final word = history.firstWhere((element) => element.id == id).word;
    await historyDao.removeHistory(word);
    await loadHistory();
  }

  @override
  Future<void> deleteSelected() async {
    await historyDao.removeHistories(selectedIds);
    clearSelection();
    await loadHistory();
  }

  Future<void> addSelectedToWordbook() async {
    final words = history
        .where((element) => selectedIds.contains(element.id))
        .map((e) => e.word);
    final existWords = await wordbookDao.wordsExist(words);
    for (final word in words) {
      if (existWords.contains(word)) {
        await Provider.of<WordbookModel>(navigatorKey.currentContext!,
                listen: false)
            .delete(word);
      } else {
        await Provider.of<WordbookModel>(navigatorKey.currentContext!,
                listen: false)
            .add(word);
      }
    }
    clearSelection();
  }

  @override
  Iterable<int> get historyIds => history.map((e) => e.id);

  @override
  Future<void> loadHistory() async {
    final history = await historyDao.getAllHistory();
    setHistory(history);
  }

  void setEnableHistory(bool value) {
    settings.setEnableHistory(value);
    notifyListeners();
  }
}

class HomeModel extends ChangeNotifier {
  int state = 0;
  String _searchWord = "";

  final searchController = SearchController();
  final searchBarFocusNode = FocusNode();

  String get searchWord => _searchWord;

  set searchWord(String word) {
    _searchWord = word;
    notifyListeners();
  }

  void focusSearchBar() {
    searchBarFocusNode.requestFocus();
    notifyListeners();
  }

  void update() {
    state++;
    notifyListeners();
  }
}

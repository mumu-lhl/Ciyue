import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:flutter/material.dart";

class HistoryModel extends ChangeNotifier {
  bool get enableHistory => settings.enableHistory;

  void addHistory(String word) async {
    if (!settings.enableHistory) {
      return;
    }
    await historyDao.addHistory(word);
    notifyListeners();
  }

  void clearHistory() {
    historyDao.clearHistory();
    notifyListeners();
  }

  void removeHistory(String word) {
    historyDao.removeHistory(word);
    notifyListeners();
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

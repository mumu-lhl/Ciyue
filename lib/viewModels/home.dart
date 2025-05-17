import "package:ciyue/main.dart";
import "package:flutter/material.dart";

class HistoryModel extends ChangeNotifier {
  void addHistory(String word) async {
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
}

class HomeModel extends ChangeNotifier {
  int state = 0;
  String _searchWord = "";

  final searchController = SearchController();
  final searchBarFocusNode = FocusNode();

  set searchWord(String word) {
    _searchWord = word;
    notifyListeners();
  }

  String get searchWord => _searchWord;

  void focusSearchBar() {
    searchBarFocusNode.requestFocus();
    notifyListeners();
  }

  void update() {
    state++;
    notifyListeners();
  }
}

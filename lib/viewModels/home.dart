import "package:ciyue/main.dart";
import "package:flutter/material.dart";

class HistoryModel extends ChangeNotifier {
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
  bool autofocus = false;
  int state = 0;
  String _searchWord = "";

  final searchController = SearchController();

  set searchWord(String word) {
    _searchWord = word;
    notifyListeners();
  }

  String get searchWord => _searchWord;

  void focusTextField() {
    autofocus = true;
    notifyListeners();
  }

  void cancelFocus() {
    autofocus = false;
    notifyListeners();
  }

  void update() {
    state++;
    notifyListeners();
  }
}

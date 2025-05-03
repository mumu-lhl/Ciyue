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
  String _searchWord = "";
  int state = 0;

  final textFieldController = TextEditingController();

  String get searchWord {
    return _searchWord;
  }

  set searchWord(String word) {
    _searchWord = word;
    notifyListeners();
  }

  void clearSearchWord() {
    textFieldController.clear();
    searchWord = "";
    notifyListeners();
  }

  void focusTextField() {
    autofocus = true;
    notifyListeners();
  }

  void setSearchWord(String word) {
    textFieldController.text = word;
    _searchWord = word;
    notifyListeners();
  }

  void update() {
    state++;
    notifyListeners();
  }
}

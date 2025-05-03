import "package:flutter/material.dart";

class HomeModel extends ChangeNotifier {
  bool autofocus = false;
  String _searchWord = "";

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
    notifyListeners();
  }
}

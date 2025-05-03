import "package:flutter/material.dart";

class HomeModel extends ChangeNotifier {
  bool autofocus = false;

  final textFieldController = TextEditingController();

  void setSearchWord(String word) {
    textFieldController.text = word;
    notifyListeners();
  }

  void clearSearchWord() {
    textFieldController.clear();
    notifyListeners();
  }

  void update() {
    notifyListeners();
  }

  void focusTextField() {
    autofocus = true;
    notifyListeners();
  }
}

import "package:flutter/material.dart";

class AIExplanationModel extends ChangeNotifier {
  int _refreshKey = 0;

  int get refreshKey => _refreshKey;

  void refreshExplanation() {
    _refreshKey++;
    notifyListeners();
  }
}

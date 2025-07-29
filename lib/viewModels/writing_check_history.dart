import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/writing_check_history.dart";
import "package:flutter/material.dart";

class WritingCheckHistoryViewModel with ChangeNotifier {
  final WritingCheckHistoryRepository _repository;

  List<WritingCheckHistoryData> _history = [];
  List<WritingCheckHistoryData> get history => _history;

  WritingCheckHistoryViewModel(this._repository) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    _history = await _repository.getAllHistory();
    notifyListeners();
  }
}

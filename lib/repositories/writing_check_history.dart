import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class WritingCheckHistoryRepository {
  final WritingCheckHistoryDao _dao;

  WritingCheckHistoryRepository(AppDatabase appDatabase)
      : _dao = WritingCheckHistoryDao(appDatabase);

  Future<int> addHistory(String inputText, String outputText) {
    return _dao.addHistory(inputText, outputText);
  }

  Future<List<WritingCheckHistoryData>> getAllHistory() {
    return _dao.getAllHistory();
  }

  Future<void> clearHistory() {
    return _dao.clearHistory();
  }

  static WritingCheckHistoryRepository of(BuildContext context) {
    return Provider.of<WritingCheckHistoryRepository>(context, listen: false);
  }
}

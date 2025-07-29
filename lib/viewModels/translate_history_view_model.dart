import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class TranslateHistoryViewModel with ChangeNotifier {
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<TranslateHistoryData> _history = [];
  List<TranslateHistoryData> get history => _history;

  TranslateHistoryViewModel() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    _isLoading = true;
    notifyListeners();

    _history = await Provider.of<TranslateHistoryDao>(
            navigatorKey.currentContext!,
            listen: false)
        .getAllHistory();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteHistory(int id) async {
    await Provider.of<TranslateHistoryDao>(navigatorKey.currentContext!,
            listen: false)
        .deleteHistory(id);
    _history.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}

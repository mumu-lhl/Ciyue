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

  final _selectedIds = <int>[];
  List<int> get selectedIds => _selectedIds;
  bool get isSelecting => _selectedIds.isNotEmpty;

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

  void toggleSelection(int id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    await Provider.of<TranslateHistoryDao>(navigatorKey.currentContext!,
            listen: false)
        .deleteHistories(_selectedIds);
    _history.removeWhere((item) => _selectedIds.contains(item.id));
    _selectedIds.clear();
    notifyListeners();
  }
}

import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class WritingCheckHistoryViewModel with ChangeNotifier {
  List<WritingCheckHistoryData> _history = [];
  List<WritingCheckHistoryData> get history => _history;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isSelecting = false;
  bool get isSelecting => _isSelecting;

  final List<int> _selectedIds = [];
  List<int> get selectedIds => _selectedIds;

  WritingCheckHistoryViewModel() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    _history = await Provider.of<WritingCheckHistoryDao>(
            navigatorKey.currentContext!,
            listen: false)
        .getAllHistory();

    _isLoading = false;
    notifyListeners();
  }

  void toggleSelection(int id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    if (_selectedIds.isEmpty) {
      _isSelecting = false;
    } else {
      _isSelecting = true;
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    _isSelecting = false;
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    await Provider.of<WritingCheckHistoryDao>(navigatorKey.currentContext!,
            listen: false)
        .deleteHistories(_selectedIds);
    _history =
        _history.where((item) => !_selectedIds.contains(item.id)).toList();
    clearSelection();
  }

  Future<void> deleteHistory(int id) async {
    await Provider.of<WritingCheckHistoryDao>(navigatorKey.currentContext!,
            listen: false)
        .deleteHistory(id);
    _history = _history.where((item) => item.id != id).toList();
    notifyListeners();
  }
}

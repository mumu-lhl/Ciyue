import "package:flutter/material.dart";

abstract class HistoryViewModel<T> extends ChangeNotifier {
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<T> _history = [];
  List<T> get history => _history;

  Iterable<int> get historyIds;

  final Set<int> _selectedIds = {};
  Set<int> get selectedIds => _selectedIds;

  bool get isSelecting => _selectedIds.isNotEmpty;

  HistoryViewModel() {
    loadHistory();
  }

  @protected
  Future<void> loadHistory();

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

  void selectAll() {
    if (_selectedIds.length == history.length) {
      _selectedIds.clear();
    } else {
      _selectedIds.addAll(historyIds);
    }
    notifyListeners();
  }

  Future<void> deleteHistory(int id);

  Future<void> deleteSelected();

  @protected
  void setHistory(List<T> history) {
    _history = history;
    if (_isLoading) {
      _isLoading = false;
    }
    notifyListeners();
  }
}

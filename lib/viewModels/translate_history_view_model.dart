import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/viewModels/history_view_model.dart";

class TranslateHistoryViewModel extends HistoryViewModel<TranslateHistoryData> {
  final TranslateHistoryDao _dao;

  TranslateHistoryViewModel([TranslateHistoryDao? dao])
    : _dao = dao ?? translateHistoryDao;

  @override
  Iterable<int> get historyIds => history.map((e) => e.id);

  @override
  Future<void> loadHistory() async {
    final history = await _dao.getAllHistory();
    setHistory(history);
  }

  @override
  Future<void> deleteHistory(int id) async {
    await _dao.deleteHistory(id);
    history.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  @override
  Future<void> deleteSelected() async {
    await _dao.deleteHistories(selectedIds.toList());
    history.removeWhere((item) => selectedIds.contains(item.id));
    clearSelection();
  }
}

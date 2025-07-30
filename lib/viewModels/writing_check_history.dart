import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/viewModels/history_view_model.dart";
import "package:provider/provider.dart";

class WritingCheckHistoryViewModel
    extends HistoryViewModel<WritingCheckHistoryData> {
  @override
  Future<void> loadHistory() async {
    final history = await Provider.of<WritingCheckHistoryDao>(
            navigatorKey.currentContext!,
            listen: false)
        .getAllHistory();
    setHistory(history);
  }

  @override
  Future<void> deleteHistory(int id) async {
    await Provider.of<WritingCheckHistoryDao>(navigatorKey.currentContext!,
            listen: false)
        .deleteHistory(id);
    history.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  @override
  Future<void> deleteSelected() async {
    await Provider.of<WritingCheckHistoryDao>(navigatorKey.currentContext!,
            listen: false)
        .deleteHistories(selectedIds.toList());
    history.removeWhere((item) => selectedIds.contains(item.id));
    clearSelection();
  }
}

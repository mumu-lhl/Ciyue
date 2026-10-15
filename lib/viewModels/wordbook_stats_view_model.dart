import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/viewModels/stats_view_model.dart";

class WordbookStatsViewModel extends StatsViewModel<WordbookData> {
  final WordbookDao _wordbookDao;

  WordbookStatsViewModel(this._wordbookDao);

  @override
  Future<List<WordbookData>> fetchData() {
    return _wordbookDao.getAllWords();
  }

  @override
  Future<Map<DateTime, int>>? fetchCounts() {
    return _wordbookDao.countWordsByDay();
  }

  @override
  DateTime getCreatedAt(WordbookData item) {
    return item.createdAt;
  }
}

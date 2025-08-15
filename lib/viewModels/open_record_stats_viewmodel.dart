import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/open_records.dart";
import "package:ciyue/viewModels/stats_view_model.dart";

class OpenRecordStatsViewModel extends StatsViewModel<OpenRecord> {
  final OpenRecordsRepository _openRecordsRepository;

  OpenRecordStatsViewModel(this._openRecordsRepository);

  @override
  Future<List<OpenRecord>> fetchData() {
    return _openRecordsRepository.getAll();
  }

  @override
  DateTime getCreatedAt(OpenRecord item) {
    return item.createdAt;
  }
}

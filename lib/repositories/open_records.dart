import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/daos.dart";

class OpenRecordsRepository {
  final _dao = OpenRecordsDao(mainDatabase);

  Future<void> add(String word) async {
    await _dao.add(word);
  }
}

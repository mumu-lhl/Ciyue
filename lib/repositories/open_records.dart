import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";

class OpenRecordsRepository {
  Future<void> add(String word) async {
    await mainDatabase.openRecordsDao.add(word);
  }

  Future<List<OpenRecord>> getAll() {
    return mainDatabase.openRecordsDao.getAll();
  }
}

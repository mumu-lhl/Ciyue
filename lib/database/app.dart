import "package:drift/drift.dart" as drift;
import "package:drift/drift.dart";
import 'package:drift_flutter/drift_flutter.dart';

part "app.g.dart";

@DriftDatabase(tables: [DictionaryList])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> add(String path) {
    return into(dictionaryList)
        .insert(DictionaryListCompanion(path: Value(path)));
  }

  Future<List<DictionaryListData>> all() {
    return (select(dictionaryList)).get();
  }

  Future<int> getId(String path) async {
    return (await ((select(dictionaryList)..where((t) => t.path.isValue(path)))
            .get()))[0]
        .id;
  }

  Future<int> remove(String path) {
    return (delete(dictionaryList)..where((t) => t.path.isValue(path))).go();
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: "dictionary_list");
  }
}

class DictionaryList extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
}

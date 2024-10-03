import "package:drift/drift.dart" as drift;
import "package:drift/drift.dart";
import "package:drift_flutter/drift_flutter.dart";

import "app_schema_versions.dart";

part "app.g.dart";

AppDatabase appDatabase() {
  final connection = driftDatabase(name: "dictionary_list");
  return AppDatabase(connection);
}

@DriftDatabase(tables: [DictionaryList])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: stepByStep(
        from1To2: (m, schema) async {
          await m.addColumn(dictionaryList, dictionaryList.fontPath);
        },
      ),
    );
  }

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

  Future<int> updateFont(int id, String? fontPath) {
    return (update(dictionaryList)..where((t) => t.id.isValue(id)))
        .write(DictionaryListCompanion(fontPath: Value(fontPath)));
  }

  Future<String?> getFontPath(int id) async {
    return (await ((select(dictionaryList)..where((t) => t.id.isValue(id)))
            .get()))[0]
        .fontPath;
  }
}

class DictionaryList extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  TextColumn get fontPath => text().nullable()();
}

import "package:ciyue/database/app/tables.dart";
import "package:ciyue/utils.dart";
import "package:drift/drift.dart" as drift;
import "package:drift/drift.dart";
import "package:drift_flutter/drift_flutter.dart";

import "app.steps.dart";

part "app.g.dart";

AppDatabase appDatabase() {
  final connection = driftDatabase(
      name: "dictionary_list",
      native: DriftNativeOptions(databaseDirectory: databaseDirectory));
  return AppDatabase(connection);
}

@DriftDatabase(
  tables: [
    DictionaryList,
    Wordbook,
    WordbookTags,
    History,
    DictGroup,
    MddAudioList,
    MddAudioResource
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: stepByStep(from1To2: (m, schema) async {
        await m.addColumn(
            schema.dictionaryList, schema.dictionaryList.fontPath);
      }, from2To3: (m, schema) async {
        await m.addColumn(
            schema.dictionaryList, schema.dictionaryList.backupPath);
      }, from3To4: (m, schema) async {
        await m.createAll();
      }, from4To5: (m, schema) async {
        await m.createTable(schema.history);
      }, from5To6: (m, schema) async {
        await m.dropColumn(schema.dictionaryList, "backup_path");
        await m.create(schema.dictGroup);
      }, from6To7: (m, schema) async {
        await m.addColumn(schema.dictionaryList, schema.dictionaryList.alias);
      }, from7To8: (m, schema) async {
        await m.addColumn(schema.wordbook, schema.wordbook.createdAt);
        await m.drop(schema.idxWordbook);
        await m.createIndex(schema.idxWordbook);
      }, from8To9: (m, schema) async {
        await m.alterTable(TableMigration(schema.wordbook));
      }, from9To10: (m, schema) async {
        await m.create(schema.mddAudioList);
        await m.create(schema.mddAudioResource);
        await m.create(schema.idxMddAudioResource);
      }),
    );
  }

  @override
  int get schemaVersion => 10;
}

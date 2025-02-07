import "package:ciyue/utils.dart";
import "package:drift/drift.dart" as drift;
import "package:drift/drift.dart";
import "package:drift_flutter/drift_flutter.dart";

import "dictionary.steps.dart";

part "dictionary.g.dart";

DictionaryDatabase dictionaryDatabase(int id) {
  final connection = driftDatabase(
      name: "dictionary_$id",
      native: DriftNativeOptions(databaseDirectory: databaseDirectory));
  return DictionaryDatabase(connection);
}

@TableIndex(name: "idx_word", columns: {#key})
class Dictionary extends Table {
  IntColumn get blockOffset => integer()();
  IntColumn get compressedSize => integer()();
  IntColumn get endOffset => integer()();
  TextColumn get key => text()();
  IntColumn get startOffset => integer()();
}

@DriftDatabase(tables: [Resource, Dictionary])
class DictionaryDatabase extends _$DictionaryDatabase {
  DictionaryDatabase(super.e);

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: stepByStep(
        from1To2: (m, schema) async {
          await m.alterTable(TableMigration(schema.wordbook));
        },
        from2To3: (m, schema) async {
          await m.addColumn(schema.wordbook, schema.wordbook.tag);

          await m.createTable(schema.wordbookTags);
          await m.createIndex(schema.idxWordbookTags);
        },
        from3To4: (m, schema) async {
          await m.deleteTable("Wordbook");
        },
      ),
    );
  }

  @override
  int get schemaVersion => 4;

  Future<DictionaryData> getOffset(String word) async {
    return (await (select(dictionary)..where((u) => u.key.isValue(word)))
        .get())[0];
  }

  Future<void> insertResource(List<ResourceCompanion> resource) async {
    await batch((batch) {
      batch.insertAll(this.resource, resource);
    });
  }

  Future<void> insertWords(List<DictionaryCompanion> dictionary) async {
    await batch((batch) {
      batch.insertAll(this.dictionary, dictionary);
    });
  }

  Future<ResourceData> readResource(String key) async {
    return (await ((select(resource)..where((u) => u.key.isValue(key)))
        .get()))[0];
  }

  Future<List<DictionaryData>> searchWord(String word) {
    return (select(dictionary)
          ..where((u) => u.key.like("${word.trimRight()}%"))
          ..limit(20))
        .get();
  }

  Future<bool> wordExist(String word) async {
    final result = await (select(dictionary)..where((u) => u.key.isValue(word))).get();
    return result.isNotEmpty;
  }
}

@TableIndex(name: "idx_data", columns: {#key})
class Resource extends Table {
  IntColumn get blockOffset => integer()();
  IntColumn get compressedSize => integer()();
  IntColumn get endOffset => integer()();
  TextColumn get key => text()();
  IntColumn get startOffset => integer()();
}

import "package:ciyue/database/dictionary/tables.dart";
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
          // ignore: experimental_member_use
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
        from4To5: (m, schema) async {
          await m.addColumn(schema.resource, schema.resource.part);
        },
      ),
    );
  }

  @override
  int get schemaVersion => 5;

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

  Future<List<ResourceData>> readResource(String key) {
    return (select(resource)..where((u) => u.key.equals(key))).get();
  }

  Future<List<String>> searchWord(String word) {
    return (select(dictionary)
          ..where((u) => u.key.like("${word.trimRight()}%"))
          ..limit(20))
        .map((row) => row.key)
        .get();
  }

  Future<bool> wordExist(String word) async {
    // First try with original word
    var result =
        await (select(dictionary)..where((u) => u.key.isValue(word))).get();

    // If not found, try with lowercase version
    if (result.isEmpty) {
      result = await (select(dictionary)
            ..where((u) => u.key.isValue(word.toLowerCase())))
          .get();
    }

    return result.isNotEmpty;
  }
}

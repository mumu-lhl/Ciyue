import "package:drift/drift.dart" as drift;
import "package:drift/drift.dart";
import "package:drift_flutter/drift_flutter.dart";

import "dictionary.steps.dart";

part "dictionary.g.dart";

DictionaryDatabase dictionaryDatabase(int id) {
  final connection = driftDatabase(name: "dictionary_$id");
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

@DriftDatabase(tables: [Wordbook, WordbookTags, Resource, Dictionary])
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
      ),
    );
  }

  @override
  int get schemaVersion => 3;

  Future<void> addAllTags(List<WordbookTag> data) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(wordbookTags, data);
    });
  }

  Future<void> addAllWords(List<WordbookData> data) async {
    await batch((batch) {
      batch.insertAll(wordbook, data);
    });
  }

  Future<int> addTag(String tag) {
    return into(wordbookTags).insert(WordbookTagsCompanion(tag: Value(tag)));
  }

  // ignore: avoid_init_to_null
  Future<int> addWord(String word, {int? tag = null}) {
    return into(wordbook)
        .insert(WordbookCompanion(tag: Value(tag), word: Value(word)));
  }

  Future<bool> existTag() async {
    return (await (select(wordbookTags)..limit(1)).get()).isNotEmpty;
  }

  Future<List<WordbookTag>> getAllTags() {
    return (select(wordbookTags)).get();
  }

  Future<List<WordbookData>> getAllWords() {
    return (select(wordbook)).get();
  }

  // ignore: avoid_init_to_null
  Future<List<WordbookData>> getAllWordsWithTag({int? tag = null}) {
    if (tag == null) {
      return (select(wordbook)
            ..where((t) => t.tag.isNull())
            ..orderBy([
              (t) => OrderingTerm(expression: t.rowId, mode: OrderingMode.desc)
            ]))
          .get();
    } else {
      return (select(wordbook)
            ..where((t) => t.tag.isValue(tag))
            ..orderBy([
              (t) => OrderingTerm(expression: t.rowId, mode: OrderingMode.desc)
            ]))
          .get();
    }
  }

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

  Future<void> removeTag(int tag) async {
    await (delete(wordbookTags)..where((t) => t.id.isValue(tag))).go();
    await (delete(wordbook)..where((t) => t.tag.isValue(tag))).go();
  }

  // ignore: avoid_init_to_null
  Future<int> removeWord(String word, {int? tag = null}) {
    if (tag == null) {
      return (delete(wordbook)..where((t) => t.word.isValue(word))).go();
    } else {
      return (delete(wordbook)
            ..where((t) => t.word.isValue(word) & t.tag.isValue(tag)))
          .go();
    }
  }

  Future<int> removeWordWithAllTags(String word) {
    return (delete(wordbook)..where((t) => t.word.isValue(word))).go();
  }

  Future<List<DictionaryData>> searchWord(String word) {
    return (select(dictionary)
          ..where((u) => u.key.like("$word%"))
          ..limit(20))
        .get();
  }

  Future<List<int>> tagsOfWord(String word) {
    return (select(wordbook)
          ..where((t) => t.word.isValue(word) & t.tag.isNotNull()))
        .map((row) => row.tag!)
        .get();
  }

  Future<bool> wordExist(String word) async {
    return (await (select(wordbook)..where((u) => u.word.isValue(word))).get())
        .isNotEmpty;
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

@TableIndex(name: "idx_wordbook", columns: {#word})
class Wordbook extends Table {
  IntColumn get tag => integer().nullable()();
  TextColumn get word => text()();
}

@TableIndex(name: "idx_wordbook_tags", columns: {#tag})
class WordbookTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tag => text().unique()();
}

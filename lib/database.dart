import "package:drift/drift.dart";
import "package:drift/drift.dart" as drift;
import 'package:drift_flutter/drift_flutter.dart';

part "database.g.dart";

@TableIndex(name: "idx_word", columns: {#key})
class Dictionary extends Table {
  TextColumn get key => text()();
  IntColumn get blockOffset => integer()();
  IntColumn get startOffset => integer()();
  IntColumn get endOffset => integer()();
  IntColumn get compressedSize => integer()();
}

@TableIndex(name: "idx_data", columns: {#key})
class Resource extends Table {
  TextColumn get key => text()();
  IntColumn get blockOffset => integer()();
  IntColumn get startOffset => integer()();
  IntColumn get endOffset => integer()();
  IntColumn get compressedSize => integer()();
}

@TableIndex(name: "idx_wordbook", columns: {#word})
class Wordbook extends Table {
  TextColumn get word => text()();
}

@DriftDatabase(tables: [Wordbook, Resource, Dictionary])
class DictionaryDatabase extends _$DictionaryDatabase {
  DictionaryDatabase(int id) : super(_openConnection(id));

  @override
  int get schemaVersion => 1;

  Future<void> insertWords(List<DictionaryCompanion> dictionary) async {
    await batch((batch) {
      batch.insertAll(this.dictionary, dictionary);
    });
  }

  Future<void> insertResource(List<ResourceCompanion> resource) async {
    await batch((batch) {
      batch.insertAll(this.resource, resource);
    });
  }

  Future<List<DictionaryData>> searchWord(String word) {
    return (select(dictionary)
          ..where((u) => u.key.like("$word%"))
          ..limit(20))
        .get();
  }

  Future<DictionaryData> getOffset(String word) async {
    return (await (select(dictionary)..where((u) => u.key.isValue(word)))
        .get())[0];
  }

  Future<ResourceData> readResource(String key) async {
    return (await ((select(resource)..where((u) => u.key.isValue(key)))
        .get()))[0];
  }

  Future<int> addWord(String word) {
    return into(wordbook).insert(WordbookCompanion(word: Value(word)));
  }

  Future<int> removeWord(String word) {
    return (delete(wordbook)..where((t) => t.word.isValue(word))).go();
  }

  Future<bool> wordExist(String word) async {
    return (await (select(wordbook)..where((u) => u.word.isValue(word))).get())
        .isNotEmpty;
  }

  Future<List<WordbookData>> getAllWords() {
    return (select(wordbook)).get();
  }

  static QueryExecutor _openConnection(int id) {
    return driftDatabase(name: "dictionary_$id");
  }
}

class DictionaryList extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
}

@DriftDatabase(tables: [DictionaryList])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> add(String path) {
    return into(dictionaryList)
        .insert(DictionaryListCompanion(path: Value(path)));
  }

  Future<int> getId(String path) async {
    return (await ((select(dictionaryList)..where((t) => t.path.isValue(path)))
            .get()))[0]
        .id;
  }

  Future<int> remove(String path) {
    return (delete(dictionaryList)..where((t) => t.path.isValue(path))).go();
  }

  Future<List<DictionaryListData>> all() {
    return (select(dictionaryList)).get();
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: "dictionary_list");
  }
}

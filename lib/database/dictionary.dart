import "package:drift/drift.dart" as drift;
import "package:drift/drift.dart";
import 'package:drift_flutter/drift_flutter.dart';

part "dictionary.g.dart";

@TableIndex(name: "idx_word", columns: {#key})
class Dictionary extends Table {
  IntColumn get blockOffset => integer()();
  IntColumn get compressedSize => integer()();
  IntColumn get endOffset => integer()();
  TextColumn get key => text()();
  IntColumn get startOffset => integer()();
}

@DriftDatabase(tables: [Wordbook, Resource, Dictionary])
class DictionaryDatabase extends _$DictionaryDatabase {
  DictionaryDatabase(int id) : super(_openConnection(id));

  @override
  int get schemaVersion => 1;

  Future<int> addWord(String word) {
    return into(wordbook).insert(WordbookCompanion(word: Value(word)));
  }

  addAllWords(WordbookData data) async {
    final words = await getAllWords();
    await into(wordbook).insertOnConflictUpdate(data);
  }

  Future<List<WordbookData>> getAllWords() {
    return (select(wordbook)).get();
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

  Future<int> removeWord(String word) {
    return (delete(wordbook)..where((t) => t.word.isValue(word))).go();
  }

  Future<List<DictionaryData>> searchWord(String word) {
    return (select(dictionary)
          ..where((u) => u.key.like("$word%"))
          ..limit(20))
        .get();
  }

  Future<bool> wordExist(String word) async {
    return (await (select(wordbook)..where((u) => u.word.isValue(word))).get())
        .isNotEmpty;
  }

  static QueryExecutor _openConnection(int id) {
    return driftDatabase(name: "dictionary_$id");
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
  TextColumn get word => text()();
}

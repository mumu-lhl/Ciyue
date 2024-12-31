import "package:drift/drift.dart" as drift;
import "package:drift/drift.dart";
import "package:drift_flutter/drift_flutter.dart";

import "app.steps.dart";

part "app.g.dart";

AppDatabase appDatabase() {
  final connection = driftDatabase(name: "dictionary_list");
  return AppDatabase(connection);
}

@DriftDatabase(tables: [DictionaryList, Wordbook, WordbookTags, History])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: stepByStep(
        from1To2: (m, schema) async {
          await m.addColumn(
              schema.dictionaryList, schema.dictionaryList.fontPath);
        },
        from2To3: (m, schema) async {
          await m.addColumn(
              schema.dictionaryList, schema.dictionaryList.backupPath);
        },
        from3To4: (m, schema) async {
          await m.createAll();
        },
        from4To5: (m, schema) async {
          await m.createTable(schema.history);
        },
      ),
    );
  }

  @override
  int get schemaVersion => 5;
}

class DictionaryList extends Table {
  TextColumn get backupPath => text().nullable()();
  TextColumn get fontPath => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
}

@DriftAccessor(tables: [DictionaryList])
class DictionaryListDao extends DatabaseAccessor<AppDatabase>
    with _$DictionaryListDaoMixin {
  DictionaryListDao(super.attachedDatabase);

  Future<int> add(String path) {
    return into(dictionaryList)
        .insert(DictionaryListCompanion(path: Value(path)));
  }

  Future<List<DictionaryListData>> all() {
    return (select(dictionaryList)).get();
  }

  Future<String?> getBackupPath(int id) async {
    return (await ((select(dictionaryList)..where((t) => t.id.isValue(id)))
            .getSingle()))
        .backupPath;
  }

  Future<String?> getFontPath(int id) async {
    return (await ((select(dictionaryList)..where((t) => t.id.isValue(id)))
            .getSingle()))
        .fontPath;
  }

  Future<int> getId(String path) async {
    return (await ((select(dictionaryList)..where((t) => t.path.isValue(path)))
            .getSingle()))
        .id;
  }

  Future<String> getPath(int id) async {
    return (await ((select(dictionaryList)..where((t) => t.id.isValue(id)))
            .getSingle()))
        .path;
  }

  Future<int> remove(String path) {
    return (delete(dictionaryList)..where((t) => t.path.isValue(path))).go();
  }

  Future<int> updateBackup(int id, String? backupPath) {
    return (update(dictionaryList)..where((t) => t.id.isValue(id)))
        .write(DictionaryListCompanion(backupPath: Value(backupPath)));
  }

  Future<int> updateFont(int id, String? fontPath) {
    return (update(dictionaryList)..where((t) => t.id.isValue(id)))
        .write(DictionaryListCompanion(fontPath: Value(fontPath)));
  }
}

class History extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text()();
}

@DriftAccessor(tables: [History])
class HistoryDao extends DatabaseAccessor<AppDatabase> with _$HistoryDaoMixin {
  HistoryDao(super.attachedDatabase);

  Future<int> addHistory(String word) async {
    await removeHistory(word);
    return into(history).insert(HistoryCompanion(word: Value(word)));
  }

  Future<void> clearHistory() {
    return delete(history).go();
  }

  Future<List<HistoryData>> getAllHistory() {
    return (select(history)
          ..orderBy(
              [(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
        .get();
  }

  Future<int> removeHistory(String word) {
    return (delete(history)..where((t) => t.word.isValue(word))).go();
  }
}

@TableIndex(name: "idx_wordbook", columns: {#word})
class Wordbook extends Table {
  IntColumn get tag => integer().nullable()();
  TextColumn get word => text()();
}

@DriftAccessor(tables: [Wordbook])
class WordbookDao extends DatabaseAccessor<AppDatabase>
    with _$WordbookDaoMixin {
  WordbookDao(super.attachedDatabase);

  Future<void> addAllWords(List<WordbookData> data) async {
    await batch((batch) {
      batch.insertAll(wordbook, data);
    });
  }

  // ignore: avoid_init_to_null
  Future<int> addWord(String word, {int? tag = null}) {
    return into(wordbook)
        .insert(WordbookCompanion(tag: Value(tag), word: Value(word)));
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

@TableIndex(name: "idx_wordbook_tags", columns: {#tag})
class WordbookTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tag => text().unique()();
}

@DriftAccessor(tables: [WordbookTags])
class WordbookTagsDao extends DatabaseAccessor<AppDatabase>
    with _$WordbookTagsDaoMixin {
  bool tagExist = false;

  WordbookTagsDao(super.attachedDatabase);

  Future<void> addAllTags(List<WordbookTag> data) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(wordbookTags, data);
    });
  }

  Future<int> addTag(String tag) {
    return into(wordbookTags).insert(WordbookTagsCompanion(tag: Value(tag)));
  }

  Future<void> existTag() async {
    tagExist = (await (select(wordbookTags)..limit(1)).get()).isNotEmpty;
  }

  Future<List<WordbookTag>> getAllTags() {
    return select(wordbookTags).get();
  }

  Future<void> removeTag(int tagId) async {
    await (delete(wordbookTags)..where((t) => t.id.isValue(tagId))).go();
  }
}

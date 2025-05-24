import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/tables.dart";
import "package:ciyue/main.dart";
import "package:drift/drift.dart";

part "daos.g.dart";

@DriftAccessor(tables: [DictGroup])
class DictGroupDao extends DatabaseAccessor<AppDatabase>
    with _$DictGroupDaoMixin {
  DictGroupDao(super.attachedDatabase);

  Future<int> addGroup(String name, List<int> dictIds) {
    return into(dictGroup).insert(
      DictGroupCompanion(
        name: Value(name),
        dictIds: Value(dictIds.join(",")),
      ),
    );
  }

  Future<List<DictGroupData>> getAllGroups() {
    return select(dictGroup).get();
  }

  Future<List<int>> getDictIds(int id) async {
    try {
      final group =
          await (select(dictGroup)..where((t) => t.id.isValue(id))).getSingle();
      return group.dictIds.split(",").map((e) => int.parse(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> removeGroup(int id) async {
    await (delete(dictGroup)..where((t) => t.id.isValue(id))).go();
  }

  Future<void> updateDictIds(int id, List<int> dictIds) {
    return (update(dictGroup)..where((t) => t.id.isValue(id)))
        .write(DictGroupCompanion(dictIds: Value(dictIds.join(","))));
  }
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

  Future<bool> dictionaryExist(String path) async {
    return (await (select(dictionaryList)..where((t) => t.path.isValue(path)))
            .get())
        .isNotEmpty;
  }

  Future<String?> getAlias(int id) async {
    final result = await (select(dictionaryList)
          ..where((t) => t.id.isValue(id)))
        .getSingleOrNull();
    return result?.alias;
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

  Future<int> updateAlias(int id, String? alias) {
    return (update(dictionaryList)..where((t) => t.id.isValue(id)))
        .write(DictionaryListCompanion(alias: Value(alias)));
  }

  Future<int> updateFont(int id, String? fontPath) {
    return (update(dictionaryList)..where((t) => t.id.isValue(id)))
        .write(DictionaryListCompanion(fontPath: Value(fontPath)));
  }
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
    return into(wordbook).insert(WordbookCompanion(
        tag: Value(tag), word: Value(word), createdAt: Value(DateTime.now())));
  }

  Future<List<WordbookData>> getAllWords() {
    return (select(wordbook)).get();
  }

  Future<List<WordbookData>> getAllWordsWithTag(
      // ignore: avoid_init_to_null
      {int? tag = null,
      bool skipTagged = false}) {
    if (tag == null) {
      if (skipTagged) {
        final subquery = selectOnly(wordbook)
          ..addColumns([wordbook.word])
          ..where(wordbook.tag.isNotNull());
        return (select(wordbook)
              ..where((t) => t.tag.isNull() & t.word.isNotInQuery(subquery))
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.rowId, mode: OrderingMode.desc)
              ]))
            .get();
      } else {
        return (select(wordbook)
              ..where((t) => t.tag.isNull())
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.rowId, mode: OrderingMode.desc)
              ]))
            .get();
      }
    } else {
      return (select(wordbook)
            ..where((t) => t.tag.isValue(tag))
            ..orderBy([
              (t) => OrderingTerm(expression: t.rowId, mode: OrderingMode.desc)
            ]))
          .get();
    }
  }

  Future<List<WordbookData>> getWordsByYearMonth(int year, int month,
      {int? tag}) {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);

    final query = select(wordbook)
      ..where((t) =>
          t.createdAt.isBetweenValues(startDate, endDate) &
          (tag == null ? t.tag.isNull() : t.tag.isValue(tag)))
      ..orderBy(
          [(t) => OrderingTerm(expression: t.rowId, mode: OrderingMode.desc)]);

    return query.get();
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

@DriftAccessor(tables: [WordbookTags])
class WordbookTagsDao extends DatabaseAccessor<AppDatabase>
    with _$WordbookTagsDaoMixin {
  bool tagExist = false;
  List<int> tagsOrder = [];

  WordbookTagsDao(super.attachedDatabase);

  Future<void> addAllTags(List<WordbookTag> data) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(wordbookTags, data);
    });
  }

  Future<void> addTag(String tag) async {
    final tagId =
        await into(wordbookTags).insert(WordbookTagsCompanion(tag: Value(tag)));
    tagsOrder.add(tagId);
    await updateTagsOrder();
  }

  Future<void> existTag() async {
    tagExist = (await (select(wordbookTags)..limit(1)).get()).isNotEmpty;
  }

  Future<List<WordbookTag>> getAllTags() {
    return select(wordbookTags).get();
  }

  Future<void> loadTagsOrder() async {
    final order = prefs.getString("tagsOrder");
    if (order == null) {
      tagsOrder = [];
    } else {
      tagsOrder = order
          .split(",")
          .where((e) => e.isNotEmpty)
          .map((e) => int.parse(e))
          .toList();
    }
  }

  Future<void> removeTag(int tagId) async {
    await (delete(wordbookTags)..where((t) => t.id.isValue(tagId))).go();

    tagsOrder.remove(tagId);
    await updateTagsOrder();
  }

  Future<void> updateTagsOrder() async {
    await prefs.setString("tagsOrder", tagsOrder.join(","));
  }
}

@DriftAccessor(tables: [MddAudioList])
class MddAudioListDao extends DatabaseAccessor<AppDatabase>
    with _$MddAudioListDaoMixin {
  MddAudioListDao(super.attachedDatabase);

  Future<int> add(String path, String title) async {
    final maxOrder = await (select(mddAudioList)
          ..orderBy([
            (t) => OrderingTerm(expression: t.order, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .getSingleOrNull();
    final order = (maxOrder?.order ?? -1) + 1;

    return into(mddAudioList).insert(MddAudioListCompanion(
        path: Value(path), title: Value(title), order: Value(order)));
  }

  Future<void> remove(int id) async {
    await (delete(mddAudioList)..where((t) => t.id.isValue(id))).go();
  }

  Future<List<MddAudioListData>> allOrdered() {
    return (select(mddAudioList)
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
  }

  Future<void> updateOrder(int id, int order) {
    return (update(mddAudioList)..where((t) => t.id.isValue(id)))
        .write(MddAudioListCompanion(order: Value(order)));
  }

  Future<bool> existMddAudio(String path) async {
    return (await (select(mddAudioList)..where((t) => t.path.isValue(path)))
            .get())
        .isNotEmpty;
  }
}

@DriftAccessor(tables: [MddAudioResource])
class MddAudioResourceDao extends DatabaseAccessor<AppDatabase>
    with _$MddAudioResourceDaoMixin {
  MddAudioResourceDao(super.attachedDatabase);

  Future<void> add(List<MddAudioResourceCompanion> data) async {
    await batch((batch) {
      batch.insertAll(mddAudioResource, data);
    });
  }

  Future<void> remove(int mddAudioId) async {
    await (delete(mddAudioResource)
          ..where((t) => t.mddAudioListId.isValue(mddAudioId)))
        .go();
  }

  Future<MddAudioResourceData?> getByKeyAndMddAudioID(
      String key, int mddAudioId) async {
    return (await (select(mddAudioResource)
          ..where(
              (t) => t.key.isValue(key) & t.mddAudioListId.isValue(mddAudioId)))
        .getSingleOrNull());
  }
}

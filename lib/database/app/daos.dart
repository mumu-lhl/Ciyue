import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/tables.dart";
import "package:dict_reader/dict_reader.dart" show normalizeKey;
import "package:drift/drift.dart";

part "daos.g.dart";

/// Splits [list] into sublists of at most [size] elements, so that generated
/// SQL stays under SQLite's variable limit (999 by default) when expanding
/// `IN` lists or multi-row inserts.
Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
  for (var i = 0; i < list.length; i += size) {
    final end = i + size < list.length ? i + size : list.length;
    yield list.sublist(i, end);
  }
}

@DriftAccessor(tables: [DictGroup])
class DictGroupDao extends DatabaseAccessor<AppDatabase>
    with _$DictGroupDaoMixin {
  DictGroupDao(super.attachedDatabase);

  Future<int> addGroup(String name, List<int> dictIds) {
    return into(dictGroup).insert(
      DictGroupCompanion(name: Value(name), dictIds: Value(dictIds.join(","))),
    );
  }

  Future<List<DictGroupData>> getAllGroups() {
    return select(dictGroup).get();
  }

  Future<List<int>> getDictIds(int id) async {
    try {
      final group = await (select(
        dictGroup,
      )..where((t) => t.id.isValue(id))).getSingle();
      return group.dictIds.split(",").map((e) => int.parse(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> removeDictIdFromAllGroups(int dictId) async {
    final groups = await getAllGroups();
    for (final group in groups) {
      final ids = group.dictIds
          .split(",")
          .where((e) => e.isNotEmpty)
          .map((e) => int.tryParse(e))
          .whereType<int>()
          .toList();
      if (ids.remove(dictId)) {
        await updateDictIds(group.id, ids);
      }
    }
  }

  Future<void> removeGroup(int id) async {
    await (delete(dictGroup)..where((t) => t.id.isValue(id))).go();
  }

  Future<void> updateDictIds(int id, List<int> dictIds) {
    return (update(dictGroup)..where((t) => t.id.isValue(id))).write(
      DictGroupCompanion(dictIds: Value(dictIds.join(","))),
    );
  }
}

@DriftAccessor(tables: [DictionaryList])
class DictionaryListDao extends DatabaseAccessor<AppDatabase>
    with _$DictionaryListDaoMixin {
  DictionaryListDao(super.attachedDatabase);

  Future<int> add(String path, String title, {int type = 1}) async {
    final maxOrder =
        await (select(dictionaryList)
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.order, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();
    final order = (maxOrder?.order ?? -1) + 1;

    return into(dictionaryList).insert(
      DictionaryListCompanion(
        path: Value(path),
        title: Value(title),
        type: Value(type),
        order: Value(order),
      ),
    );
  }

  Future<List<DictionaryListData>> all() {
    return (select(
      dictionaryList,
    )..orderBy([(t) => OrderingTerm(expression: t.order)])).get();
  }

  Future<void> updateOrder(List<DictionaryListData> dictionaries) {
    return batch((batch) {
      for (var i = 0; i < dictionaries.length; i++) {
        batch.update(
          dictionaryList,
          DictionaryListCompanion(order: Value(i)),
          where: (t) => t.id.isValue(dictionaries[i].id),
        );
      }
    });
  }

  Future<bool> dictionaryExist(String path) async {
    return (await (select(dictionaryList)
              ..where((t) => t.path.isValue(path))
              ..limit(1))
            .get())
        .isNotEmpty;
  }

  Future<String?> getTitle(int id) async {
    final result = await (select(
      dictionaryList,
    )..where((t) => t.id.isValue(id))).getSingleOrNull();
    return result?.title;
  }

  Future<String?> getFontPath(int id) async {
    return (await ((select(
      dictionaryList,
    )..where((t) => t.id.isValue(id))).getSingle())).fontPath;
  }

  Future<int> getId(String path) async {
    return (await ((select(
      dictionaryList,
    )..where((t) => t.path.isValue(path))).getSingle())).id;
  }

  Future<String?> getPath(int id) async {
    return (await ((select(
      dictionaryList,
    )..where((t) => t.id.isValue(id))).getSingleOrNull()))?.path;
  }

  Future<int> remove(String path) {
    return (delete(dictionaryList)..where((t) => t.path.isValue(path))).go();
  }

  Future<int> updateTitle(int id, String? alias) {
    return (update(dictionaryList)..where((t) => t.id.isValue(id))).write(
      DictionaryListCompanion(title: Value(alias)),
    );
  }

  Future<int> updateFont(int id, String? fontPath) {
    return (update(dictionaryList)..where((t) => t.id.isValue(id))).write(
      DictionaryListCompanion(fontPath: Value(fontPath)),
    );
  }

  Future<int> getType(int id) async {
    return (await ((select(
      dictionaryList,
    )..where((t) => t.id.isValue(id))).getSingle())).type;
  }
}

@DriftAccessor(tables: [HunspellSource])
class HunspellSourceDao extends DatabaseAccessor<AppDatabase>
    with _$HunspellSourceDaoMixin {
  HunspellSourceDao(super.attachedDatabase);

  Future<List<HunspellSourceData>> all() {
    return (select(
      hunspellSource,
    )..orderBy([(row) => OrderingTerm(expression: row.order)])).get();
  }

  Future<List<HunspellSourceData>> enabled() {
    return (select(hunspellSource)
          ..where((row) => row.enabled.equals(true))
          ..orderBy([(row) => OrderingTerm(expression: row.order)]))
        .get();
  }

  Future<int> add({
    required String name,
    required String affPath,
    required String dicPath,
    String? language,
    bool enabled = false,
    bool twoPassLookup = false,
  }) async {
    final maxOrder =
        await (select(hunspellSource)
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.order,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();

    return into(hunspellSource).insert(
      HunspellSourceCompanion(
        name: Value(name),
        affPath: Value(affPath),
        dicPath: Value(dicPath),
        language: Value(language),
        enabled: Value(enabled),
        order: Value((maxOrder?.order ?? -1) + 1),
        twoPassLookup: Value(twoPassLookup),
      ),
    );
  }

  Future<bool> exists(String affPath, String dicPath) async {
    return (await (select(hunspellSource)..where(
              (row) =>
                  row.affPath.isValue(affPath) & row.dicPath.isValue(dicPath),
            ))
            .get())
        .isNotEmpty;
  }

  Future<void> setEnabled(int id, bool enabled) {
    return (update(hunspellSource)..where((row) => row.id.isValue(id))).write(
      HunspellSourceCompanion(enabled: Value(enabled)),
    );
  }

  Future<void> setTwoPassLookup(int id, bool twoPassLookup) {
    return (update(hunspellSource)..where((row) => row.id.isValue(id))).write(
      HunspellSourceCompanion(twoPassLookup: Value(twoPassLookup)),
    );
  }

  Future<void> updateOrder(List<HunspellSourceData> sources) {
    return batch((batch) {
      for (var i = 0; i < sources.length; i++) {
        batch.update(
          hunspellSource,
          HunspellSourceCompanion(order: Value(i)),
          where: (row) => row.id.isValue(sources[i].id),
        );
      }
    });
  }

  Future<void> remove(int id) {
    return (delete(hunspellSource)..where((row) => row.id.isValue(id))).go();
  }
}

@DriftAccessor(tables: [History])
class HistoryDao extends DatabaseAccessor<AppDatabase> with _$HistoryDaoMixin {
  HistoryDao(super.attachedDatabase);

  Future<int> addHistory(String word) {
    // Store the NFC spelling so that the same visible word typed on a device
    // producing NFD input does not create a second history row.
    final key = normalizeKey(word);
    // Delete + insert in one transaction: fewer journal syncs and atomic.
    return transaction(() async {
      await removeHistory(key);
      return into(history).insert(HistoryCompanion(word: Value(key)));
    });
  }

  /// Batch import of history words, oldest first. Deduplicates (keeping the
  /// newest occurrence) and replaces existing rows for these words, matching
  /// the semantics of calling [addHistory] in a loop but in far fewer
  /// statements.
  Future<void> addAllHistory(List<String> words) async {
    if (words.isEmpty) {
      return;
    }
    final seen = <String>{};
    final newestFirst = <String>[];
    for (var i = words.length - 1; i >= 0; i--) {
      final word = normalizeKey(words[i]);
      if (seen.add(word)) {
        newestFirst.add(word);
      }
    }
    // Insert oldest first so ids ascend with recency (matches ORDER BY id
    // DESC used by getAllHistory).
    final ordered = newestFirst.reversed.toList();
    // Delete in chunks to stay under SQLite's variable limit.
    for (final chunk in _chunks(ordered, 500)) {
      await (delete(history)..where((t) => t.word.isIn(chunk))).go();
    }
    // HistoryCompanion carries a single variable (word) per row.
    await batch((b) {
      for (final chunk in _chunks([
        for (final word in ordered) HistoryCompanion(word: Value(word)),
      ], 999)) {
        b.insertAll(history, chunk);
      }
    });
  }

  Future<void> clearHistory() {
    return delete(history).go();
  }

  Future<List<HistoryData>> getAllHistory() {
    return (select(history)..orderBy([
          (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
        ]))
        .get();
  }

  Future<int> removeHistory(String word) {
    return (delete(
      history,
    )..where((t) => t.word.isValue(normalizeKey(word)))).go();
  }

  Future<void> removeHistories(Iterable<int> ids) {
    return (delete(history)..where((t) => t.id.isIn(ids))).go();
  }
}

@DriftAccessor(tables: [Flashcards, FlashcardReviewLogs, Wordbook])
class FlashcardDao extends DatabaseAccessor<AppDatabase>
    with _$FlashcardDaoMixin {
  FlashcardDao(super.attachedDatabase);

  Future<Flashcard?> getCard(String word) {
    return (select(
      flashcards,
    )..where((row) => row.word.equals(word))).getSingleOrNull();
  }

  Future<List<Flashcard>> getDueCards({required DateTime now, int? tag}) async {
    // Use a subquery instead of expanding active words into IN (?,...):
    // avoids the SQLite variable limit (crash over ~999 words) and the
    // full wordbook table pull.
    final wordbookQuery = selectOnly(wordbook)..addColumns([wordbook.word]);
    if (tag != null) {
      wordbookQuery.where(wordbook.tag.equals(tag));
    }
    return (select(flashcards)
          ..where(
            (row) =>
                row.word.isInQuery(wordbookQuery) &
                row.due.isSmallerOrEqualValue(now),
          )
          ..orderBy([(row) => OrderingTerm(expression: row.due)]))
        .get();
  }

  Future<List<String>> getNewWords({required int limit, int? tag}) async {
    if (limit <= 0) return [];
    // NOT IN subquery: no full table pulls, no Dart-side diff, limit in SQL.
    // DISTINCT because the same word can appear under multiple tags.
    final flashcardsQuery = selectOnly(flashcards)
      ..addColumns([flashcards.word]);
    final query = selectOnly(wordbook, distinct: true)
      ..addColumns([wordbook.word])
      ..where(wordbook.word.isNotInQuery(flashcardsQuery))
      ..orderBy([OrderingTerm(expression: wordbook.createdAt)])
      ..limit(limit);
    if (tag != null) query.where(wordbook.tag.equals(tag));
    return query.map((row) => row.read(wordbook.word)!).get();
  }

  Future<int> countIntroduced({
    required DateTime start,
    required DateTime end,
  }) async {
    final expression = flashcards.word.count();
    final query = selectOnly(flashcards)
      ..addColumns([expression])
      ..where(
        flashcards.introducedAt.isBiggerOrEqualValue(start) &
            flashcards.introducedAt.isSmallerThanValue(end),
      );
    return (await query.getSingle()).read(expression) ?? 0;
  }

  Future<void> putCard({
    required String word,
    required int state,
    int? step,
    double? stability,
    double? difficulty,
    required DateTime due,
    DateTime? lastReview,
    required DateTime introducedAt,
  }) {
    return into(flashcards).insertOnConflictUpdate(
      FlashcardsCompanion(
        word: Value(word),
        state: Value(state),
        step: Value(step),
        stability: Value(stability),
        difficulty: Value(difficulty),
        due: Value(due),
        lastReview: Value(lastReview),
        introducedAt: Value(introducedAt),
      ),
    );
  }

  Future<int> addReviewLog({
    required String word,
    required int rating,
    required DateTime reviewedAt,
    int? durationMs,
  }) {
    return into(flashcardReviewLogs).insert(
      FlashcardReviewLogsCompanion(
        word: Value(word),
        rating: Value(rating),
        reviewedAt: Value(reviewedAt),
        durationMs: Value(durationMs),
      ),
    );
  }

  Future<int> saveReview({
    required Flashcard card,
    required int rating,
    required DateTime reviewedAt,
    int? durationMs,
  }) {
    return transaction(() async {
      await putCard(
        word: card.word,
        state: card.state,
        step: card.step,
        stability: card.stability,
        difficulty: card.difficulty,
        due: card.due,
        lastReview: card.lastReview,
        introducedAt: card.introducedAt,
      );
      return addReviewLog(
        word: card.word,
        rating: rating,
        reviewedAt: reviewedAt,
        durationMs: durationMs,
      );
    });
  }

  Future<void> undoReview({
    required Flashcard previousCard,
    required int logId,
  }) {
    return transaction(() async {
      await putCard(
        word: previousCard.word,
        state: previousCard.state,
        step: previousCard.step,
        stability: previousCard.stability,
        difficulty: previousCard.difficulty,
        due: previousCard.due,
        lastReview: previousCard.lastReview,
        introducedAt: previousCard.introducedAt,
      );
      await deleteReviewLog(logId);
    });
  }

  Future<void> deleteReviewLog(int id) async {
    await (delete(flashcardReviewLogs)..where((row) => row.id.equals(id))).go();
  }

  Future<List<FlashcardReviewLog>> getReviewLogs() => (select(
    flashcardReviewLogs,
  )..orderBy([(row) => OrderingTerm.desc(row.reviewedAt)])).get();

  Future<int> countReviews({
    required DateTime start,
    required DateTime end,
  }) async {
    final expression = flashcardReviewLogs.id.count();
    final query = selectOnly(flashcardReviewLogs)
      ..addColumns([expression])
      ..where(
        flashcardReviewLogs.reviewedAt.isBiggerOrEqualValue(start) &
            flashcardReviewLogs.reviewedAt.isSmallerThanValue(end),
      );
    return (await query.getSingle()).read(expression) ?? 0;
  }

  Future<List<Flashcard>> getAllCards() => select(flashcards).get();

  Future<void> addAllCards(List<Flashcard> cards) => batch((batch) {
    // 8 variables per row: stay under SQLite's variable limit.
    for (final chunk in _chunks(cards, 999 ~/ 8)) {
      batch.insertAllOnConflictUpdate(flashcards, chunk);
    }
  });

  Future<void> addAllReviewLogs(List<FlashcardReviewLog> logs) =>
      batch((batch) {
        for (final log in logs) {
          batch.insert(
            flashcardReviewLogs,
            FlashcardReviewLogsCompanion.insert(
              word: log.word,
              rating: log.rating,
              reviewedAt: log.reviewedAt,
              durationMs: Value(log.durationMs),
            ),
          );
        }
      });
}

@DriftAccessor(tables: [Wordbook])
class WordbookDao extends DatabaseAccessor<AppDatabase>
    with _$WordbookDaoMixin {
  WordbookDao(super.attachedDatabase);

  Future<void> addAllWords(List<WordbookData> data) async {
    if (data.isEmpty) return;

    // Normalise before the dedup pass: a backup written on a device with a
    // different input method may carry the decomposed spelling of a word that
    // is already in the wordbook.
    data = [
      for (final entry in data) entry.copyWith(word: normalizeKey(entry.word)),
    ];

    // Query only the words being inserted (not the full table) for dedup,
    // chunked to stay under SQLite's variable limit.
    final wordsToCheck = data.map((e) => e.word).toSet().toList();
    final existingSet = <String>{};
    for (final chunk in _chunks(wordsToCheck, 500)) {
      final existing = await (select(
        wordbook,
      )..where((t) => t.word.isIn(chunk))).get();
      existingSet.addAll(existing.map((e) => "${e.word}_${e.tag}"));
    }

    final toInsert = data
        .where((e) => !existingSet.contains("${e.word}_${e.tag}"))
        .toList();

    if (toInsert.isNotEmpty) {
      await batch((batch) {
        // 3 variables per row (createdAt, tag, word): chunk the insert.
        for (final chunk in _chunks(toInsert, 999 ~/ 3)) {
          // Unique index on (word, tag) handles race-condition duplicates.
          batch.insertAll(wordbook, chunk, mode: InsertMode.insertOrIgnore);
        }
      });
    }
  }

  Future<int> countTotalWords() async {
    final count = countAll();
    final query = selectOnly(wordbook)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Count words grouped by day in SQL (not full table pull + Dart aggregation).
  /// Grouped by *local* day so 00:00–08:00 entries in UTC+8 land on the right
  /// calendar day, matching the Dart-side fallback in StatsViewModel.
  Future<Map<DateTime, int>> countWordsByDay() async {
    final day = wordbook.createdAt.modify(DateTimeModifier.localTime()).date;
    final count = wordbook.word.count();
    final query = selectOnly(wordbook)
      ..addColumns([day, count])
      ..groupBy([day]);
    final rows = await query.get();
    return {
      for (final row in rows)
        DateTime.parse("${row.read(day)}T00:00:00Z"): row.read(count)!,
    };
  }

  Future<int> addWord(String word, {int? tag}) {
    return into(wordbook).insert(
      WordbookCompanion(
        tag: Value(tag),
        word: Value(normalizeKey(word)),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<WordbookData>> getAllWords() {
    return (select(wordbook)).get();
  }

  Future<List<WordbookData>> getAllWordsWithTag({
    int? tag,
    bool skipTagged = false,
  }) {
    if (tag == null) {
      if (skipTagged) {
        final subquery = selectOnly(wordbook)
          ..addColumns([wordbook.word])
          ..where(wordbook.tag.isNotNull());
        return (select(wordbook)
              ..where((t) => t.tag.isNull() & t.word.isNotInQuery(subquery))
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.rowId, mode: OrderingMode.desc),
              ]))
            .get();
      } else {
        return (select(wordbook)
              ..where((t) => t.tag.isNull())
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.rowId, mode: OrderingMode.desc),
              ]))
            .get();
      }
    } else {
      return (select(wordbook)
            ..where((t) => t.tag.isValue(tag))
            ..orderBy([
              (t) => OrderingTerm(expression: t.rowId, mode: OrderingMode.desc),
            ]))
          .get();
    }
  }

  Future<List<WordbookData>> getWordsByYearMonth(
    int year,
    int month, {
    int? tag,
  }) {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);

    final query = select(wordbook)
      ..where(
        (t) =>
            t.createdAt.isBetweenValues(startDate, endDate) &
            (tag == null ? t.tag.isNull() : t.tag.isValue(tag)),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.rowId, mode: OrderingMode.desc),
      ]);

    return query.get();
  }

  Future<List<WordbookData>> searchWords(String query) {
    return (select(wordbook)
          ..where((t) => t.word.like("$query%"))
          ..limit(40))
        .get();
  }

  /// Get candidates for fuzzy search: SQL LIKE pre-filter (uses idx_wordbook)
  /// to limit the candidate set instead of pulling the full table.
  /// Falls back to full table only if the pre-filter returns too few.
  Future<List<WordbookData>> searchWordsForFuzzy(String query) async {
    // Try substring match first (fast, indexed).
    var candidates =
        await (select(wordbook)
              ..where((t) => t.word.like("%$query%"))
              ..limit(200))
            .get();
    if (candidates.length < 50) {
      // Too few substring matches; fall back to full table for fuzzy.
      candidates = await getAllWords();
    }
    return candidates;
  }

  Future<int> removeWord(String word, {int? tag}) {
    final key = normalizeKey(word);
    if (tag == null) {
      return (delete(
        wordbook,
      )..where((t) => t.word.isValue(key) & t.tag.isNull())).go();
    } else {
      return (delete(
        wordbook,
      )..where((t) => t.word.isValue(key) & t.tag.isValue(tag))).go();
    }
  }

  Future<int> removeWordWithAllTags(String word) {
    return (delete(
      wordbook,
    )..where((t) => t.word.isValue(normalizeKey(word)))).go();
  }

  Future<void> removeWords(List<WordbookData> words) async {
    await batch((batch) {
      for (final wordData in words) {
        final key = normalizeKey(wordData.word);
        if (wordData.tag == null) {
          batch.deleteWhere(
            wordbook,
            (row) => row.word.isValue(key) & row.tag.isNull(),
          );
        } else {
          batch.deleteWhere(
            wordbook,
            (row) => row.word.isValue(key) & row.tag.isValue(wordData.tag!),
          );
        }
      }
    });
  }

  Future<List<int>> tagsOfWord(String word) {
    return (select(
          wordbook,
        )..where((t) => t.word.isValue(normalizeKey(word)) & t.tag.isNotNull()))
        .map((row) => row.tag!)
        .get();
  }

  Future<bool> wordExist(String word) async {
    return (await (select(wordbook)
              ..where((u) => u.word.isValue(normalizeKey(word)))
              ..limit(1))
            .get())
        .isNotEmpty;
  }

  Future<Set<String>> wordsExist(Iterable<String> words) async {
    final result = <String>{};
    // Chunk the IN list to stay under SQLite's variable limit.
    for (final chunk in _chunks([
      for (final word in words) normalizeKey(word),
    ], 500)) {
      final rows = await (select(
        wordbook,
      )..where((u) => u.word.isIn(chunk))).get();
      result.addAll(rows.map((e) => e.word));
    }
    return result;
  }
}

@DriftAccessor(tables: [WordbookTags, Wordbook])
class WordbookTagsDao extends DatabaseAccessor<AppDatabase>
    with _$WordbookTagsDaoMixin {
  bool tagExist = false;
  List<int> tagsOrder = [];

  WordbookTagsDao(super.attachedDatabase);

  Future<void> addAllTags(List<WordbookTag> data) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(wordbookTags, data);
    });
    // Refresh tagsOrder to include imported tags. Otherwise the in-memory
    // order goes stale after backup restore / cloud sync import.
    final allTags = await select(wordbookTags).get();
    final existingIds = tagsOrder.toSet();
    for (final tag in allTags) {
      if (!existingIds.contains(tag.id)) {
        tagsOrder.add(tag.id);
      }
    }
    await updateTagsOrder();
  }

  Future<void> addTag(String tag) async {
    final tagId = await into(wordbookTags)
        .insert(WordbookTagsCompanion(tag: Value(tag)));
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

    // Clear the tag from words that used it, otherwise wordbook.tag dangles.
    await (update(wordbook)..where((t) => t.tag.isValue(tagId))).write(
      const WordbookCompanion(tag: Value(null)),
    );

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
    final maxOrder =
        await (select(mddAudioList)
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.order, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();
    final order = (maxOrder?.order ?? -1) + 1;

    return into(mddAudioList).insert(
      MddAudioListCompanion(
        path: Value(path),
        title: Value(title),
        order: Value(order),
      ),
    );
  }

  Future<void> remove(int id) async {
    await (delete(mddAudioList)..where((t) => t.id.isValue(id))).go();
  }

  Future<List<MddAudioListData>> allOrdered() {
    return (select(
      mddAudioList,
    )..orderBy([(t) => OrderingTerm(expression: t.order)])).get();
  }

  Future<void> updateOrder(int id, int order) {
    return (update(mddAudioList)..where((t) => t.id.isValue(id))).write(
      MddAudioListCompanion(order: Value(order)),
    );
  }

  Future<bool> existMddAudio(String path) async {
    return (await (select(
      mddAudioList,
    )..where((t) => t.path.isValue(path))).get()).isNotEmpty;
  }
}

@DriftAccessor(tables: [MddAudioResource])
class MddAudioResourceDao extends DatabaseAccessor<AppDatabase>
    with _$MddAudioResourceDaoMixin {
  MddAudioResourceDao(super.attachedDatabase);

  Future<void> add(List<MddAudioResourceCompanion> data) async {
    await batch((batch) {
      // 6 variables per row: stay under SQLite's variable limit.
      for (final chunk in _chunks(data, 999 ~/ 6)) {
        batch.insertAll(mddAudioResource, chunk);
      }
    });
  }

  Future<void> remove(int mddAudioId) async {
    await (delete(
      mddAudioResource,
    )..where((t) => t.mddAudioListId.isValue(mddAudioId))).go();
  }

  Future<List<MddAudioResourceData>?> getByKeyAndMddAudioID(
    String key,
    int mddAudioId,
  ) async {
    return (await (select(mddAudioResource)..where(
          (t) => t.key.isValue(key) & t.mddAudioListId.isValue(mddAudioId),
        ))
        .get());
  }

  Future<int> countByMddAudioID(int mddAudioId) async {
    final count = mddAudioResource.key.count();
    final row =
        await (selectOnly(mddAudioResource)
              ..addColumns([count])
              ..where(mddAudioResource.mddAudioListId.isValue(mddAudioId)))
            .getSingle();
    return row.read(count) ?? 0;
  }
}

@DriftAccessor(tables: [AiExplanations])
class AiExplanationDao extends DatabaseAccessor<AppDatabase>
    with _$AiExplanationDaoMixin {
  AiExplanationDao(super.attachedDatabase);

  Future<int> insertAiExplanation(AiExplanation explanation) {
    return into(aiExplanations).insert(explanation);
  }

  Future<AiExplanation?> getAiExplanation(String word) {
    return (select(
      aiExplanations,
    )..where((t) => t.word.isValue(word))).getSingleOrNull();
  }

  Future<int> updateAiExplanation(AiExplanation explanation) {
    return (update(
      aiExplanations,
    )..where((t) => t.word.isValue(explanation.word))).write(
      AiExplanationsCompanion(
        word: Value(explanation.word),
        explanation: Value(explanation.explanation),
      ),
    );
  }

  Future<int> deleteAiExplanation(String word) {
    return (delete(aiExplanations)..where((t) => t.word.isValue(word))).go();
  }
}

@DriftAccessor(tables: [WritingCheckHistory])
class WritingCheckHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$WritingCheckHistoryDaoMixin {
  WritingCheckHistoryDao(super.attachedDatabase);

  Future<int> addHistory(String inputText, String outputText) {
    return into(writingCheckHistory).insert(
      WritingCheckHistoryCompanion(
        inputText: Value(inputText),
        outputText: Value(outputText),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> addAllHistory(List<WritingCheckHistoryData> data) async {
    if (data.isEmpty) return;

    // Dedup the batch in memory first (cheap).
    final seen = <String>{};
    final deduped = data.where((e) {
      final key =
          "${e.inputText}_${e.outputText}_${e.createdAt.millisecondsSinceEpoch}";
      return seen.add(key);
    }).toList();

    // Query only key columns for existing entries (not full rows with
    // potentially long outputText), chunked to stay under SQLite's
    // variable limit.
    final inputTexts = deduped.map((e) => e.inputText).toSet().toList();
    final existingKeys = <String>[];
    for (final chunk in _chunks(inputTexts, 500)) {
      final rows =
          await (selectOnly(writingCheckHistory)
                ..addColumns([
                  writingCheckHistory.inputText,
                  writingCheckHistory.outputText,
                  writingCheckHistory.createdAt,
                ])
                ..where(writingCheckHistory.inputText.isIn(chunk)))
              .map(
                (row) =>
                    "${row.read(writingCheckHistory.inputText)}_${row.read(writingCheckHistory.outputText)}_${row.read(writingCheckHistory.createdAt)!.millisecondsSinceEpoch}",
              )
              .get();
      existingKeys.addAll(rows);
    }
    final existingSet = existingKeys.toSet();

    final toInsert = deduped.where((e) {
      final key =
          "${e.inputText}_${e.outputText}_${e.createdAt.millisecondsSinceEpoch}";
      return !existingSet.contains(key);
    }).toList();

    if (toInsert.isNotEmpty) {
      await batch((batch) {
        // 4 variables per row: stay under SQLite's variable limit.
        for (final chunk in _chunks(toInsert, 999 ~/ 4)) {
          batch.insertAll(writingCheckHistory, chunk);
        }
      });
    }
  }

  Future<List<WritingCheckHistoryData>> getAllHistory() {
    return (select(writingCheckHistory)..orderBy([
          (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
        ]))
        .get();
  }

  Future<void> clearHistory() {
    return delete(writingCheckHistory).go();
  }

  Future<void> deleteHistory(int id) {
    return (delete(writingCheckHistory)..where((t) => t.id.isValue(id))).go();
  }

  Future<void> deleteHistories(List<int> ids) {
    return (delete(writingCheckHistory)..where((t) => t.id.isIn(ids))).go();
  }
}

@DriftAccessor(tables: [TranslateHistory])
class TranslateHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$TranslateHistoryDaoMixin {
  TranslateHistoryDao(super.attachedDatabase);

  Future<int> addHistory(String inputText) {
    // Delete + insert in one transaction: fewer journal syncs and atomic.
    return transaction(() async {
      await deleteHistoryByInputText(inputText);
      return into(translateHistory).insert(
        TranslateHistoryCompanion(
          inputText: Value(inputText),
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> addAllHistory(List<TranslateHistoryData> data) async {
    if (data.isEmpty) return;

    // Unique index on inputText: use insertOrIgnore, no pre-read needed.
    await batch((batch) {
      // 3 variables per row: stay under SQLite's variable limit.
      for (final chunk in _chunks(data, 999 ~/ 3)) {
        batch.insertAll(
          translateHistory,
          chunk,
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<List<TranslateHistoryData>> getAllHistory() {
    return (select(translateHistory)..orderBy([
          (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
        ]))
        .get();
  }

  Future<void> clearHistory() {
    return delete(translateHistory).go();
  }

  Future<void> deleteHistory(int id) {
    return (delete(translateHistory)..where((t) => t.id.isValue(id))).go();
  }

  Future<void> deleteHistories(List<int> ids) {
    return (delete(translateHistory)..where((t) => t.id.isIn(ids))).go();
  }

  Future<int> deleteHistoryByInputText(String inputText) {
    return (delete(
      translateHistory,
    )..where((t) => t.inputText.isValue(inputText))).go();
  }
}

@DriftAccessor(tables: [OpenRecords])
class OpenRecordsDao extends DatabaseAccessor<AppDatabase>
    with _$OpenRecordsDaoMixin {
  OpenRecordsDao(super.attachedDatabase);

  Future<void> add(String word) async {
    await into(openRecords).insert(
      OpenRecordsCompanion(word: Value(word), createdAt: Value(DateTime.now())),
    );
  }

  Future<List<OpenRecord>> getAll() {
    return select(openRecords).get();
  }

  /// Count records grouped by *local* day (see countWordsByDay).
  Future<Map<DateTime, int>> countByDay() async {
    final day = openRecords.createdAt.modify(DateTimeModifier.localTime()).date;
    final count = openRecords.word.count();
    final query = selectOnly(openRecords)
      ..addColumns([day, count])
      ..groupBy([day]);
    final rows = await query.get();
    return {
      for (final row in rows)
        DateTime.parse("${row.read(day)}T00:00:00Z"): row.read(count)!,
    };
  }
}

@DriftAccessor(tables: [QuizMistakes])
class QuizMistakeDao extends DatabaseAccessor<AppDatabase>
    with _$QuizMistakeDaoMixin {
  QuizMistakeDao(super.attachedDatabase);

  /// Record a wrong answer. Same word answered wrong again bumps it to the
  /// top (delete + insert) so review order reflects recency. Word matching
  /// is case-insensitive: AI-generated questions don't always reproduce
  /// the stored word's exact casing.
  Future<void> addMistake({
    required String word,
    required String questionType,
    required String question,
    required String correctAnswer,
    String? userAnswer,
    List<String>? options,
  }) {
    return transaction(() async {
      await (delete(
        quizMistakes,
      )..where((t) => t.word.lower().isValue(word.trim().toLowerCase()))).go();
      await into(quizMistakes).insert(
        QuizMistakesCompanion(
          word: Value(word.trim()),
          questionType: Value(questionType),
          question: Value(question),
          correctAnswer: Value(correctAnswer),
          userAnswer: Value(userAnswer),
          options: Value(options == null ? null : jsonEncode(options)),
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<List<QuizMistake>> getMistakes({int? limit}) {
    final query = select(quizMistakes)
      ..orderBy([
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<int> getMistakeCount() async {
    final count = quizMistakes.id.count();
    final row = await (selectOnly(
      quizMistakes,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Remove a word from mistakes once the user answers it correctly.
  /// Case-insensitive, matching [addMistake].
  Future<void> removeMistake(String word) {
    return (delete(
      quizMistakes,
    )..where((t) => t.word.lower().isValue(word.trim().toLowerCase()))).go();
  }

  Future<void> clearMistakes() {
    return delete(quizMistakes).go();
  }
}

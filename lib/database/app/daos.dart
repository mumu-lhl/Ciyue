import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/tables.dart";
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

  Future<int> add(String path, String title) async {
    final maxOrder = await (select(dictionaryList)
          ..orderBy([
            (t) => OrderingTerm(expression: t.order, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .getSingleOrNull();
    final order = (maxOrder?.order ?? -1) + 1;

    return into(dictionaryList).insert(DictionaryListCompanion(
        path: Value(path),
        title: Value(title),
        type: const Value(1),
        order: Value(order)));
  }

  Future<List<DictionaryListData>> all() {
    return (select(dictionaryList)
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
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
    return (await (select(dictionaryList)..where((t) => t.path.isValue(path)))
            .get())
        .isNotEmpty;
  }

  Future<String?> getTitle(int id) async {
    final result = await (select(dictionaryList)
          ..where((t) => t.id.isValue(id)))
        .getSingleOrNull();
    return result?.title;
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

  Future<int> updateTitle(int id, String? alias) {
    return (update(dictionaryList)..where((t) => t.id.isValue(id)))
        .write(DictionaryListCompanion(title: Value(alias)));
  }

  Future<int> updateFont(int id, String? fontPath) {
    return (update(dictionaryList)..where((t) => t.id.isValue(id)))
        .write(DictionaryListCompanion(fontPath: Value(fontPath)));
  }

  Future<int> getType(int id) async {
    return (await ((select(dictionaryList)..where((t) => t.id.isValue(id)))
            .getSingle()))
        .type;
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

  Future<void> removeHistories(Iterable<int> ids) {
    return (delete(history)..where((t) => t.id.isIn(ids))).go();
  }
}

@DriftAccessor(tables: [Flashcards, FlashcardReviewLogs, Wordbook])
class FlashcardDao extends DatabaseAccessor<AppDatabase>
    with _$FlashcardDaoMixin {
  FlashcardDao(super.attachedDatabase);

  Future<Flashcard?> getCard(String word) {
    return (select(flashcards)..where((row) => row.word.equals(word)))
        .getSingleOrNull();
  }

  Future<List<Flashcard>> getDueCards({
    required DateTime now,
    int? tag,
  }) async {
    final activeWords = await _activeWords(tag: tag);
    if (activeWords.isEmpty) return [];
    return (select(flashcards)
          ..where((row) =>
              row.word.isIn(activeWords) & row.due.isSmallerOrEqualValue(now))
          ..orderBy([(row) => OrderingTerm(expression: row.due)]))
        .get();
  }

  Future<List<String>> getNewWords({required int limit, int? tag}) async {
    if (limit <= 0) return [];
    final query = select(wordbook)
      ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]);
    if (tag != null) query.where((row) => row.tag.equals(tag));
    final words = await query.get();
    final existing =
        (await select(flashcards).get()).map((e) => e.word).toSet();
    final result = <String>[];
    for (final entry in words) {
      if (!existing.contains(entry.word) && !result.contains(entry.word)) {
        result.add(entry.word);
        if (result.length == limit) break;
      }
    }
    return result;
  }

  Future<int> countIntroduced({
    required DateTime start,
    required DateTime end,
  }) async {
    final expression = flashcards.word.count();
    final query = selectOnly(flashcards)
      ..addColumns([expression])
      ..where(flashcards.introducedAt.isBiggerOrEqualValue(start) &
          flashcards.introducedAt.isSmallerThanValue(end));
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
    return into(flashcards).insertOnConflictUpdate(FlashcardsCompanion(
      word: Value(word),
      state: Value(state),
      step: Value(step),
      stability: Value(stability),
      difficulty: Value(difficulty),
      due: Value(due),
      lastReview: Value(lastReview),
      introducedAt: Value(introducedAt),
    ));
  }

  Future<int> addReviewLog({
    required String word,
    required int rating,
    required DateTime reviewedAt,
    int? durationMs,
  }) {
    return into(flashcardReviewLogs).insert(FlashcardReviewLogsCompanion(
      word: Value(word),
      rating: Value(rating),
      reviewedAt: Value(reviewedAt),
      durationMs: Value(durationMs),
    ));
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

  Future<List<FlashcardReviewLog>> getReviewLogs() =>
      (select(flashcardReviewLogs)
            ..orderBy([(row) => OrderingTerm.desc(row.reviewedAt)]))
          .get();

  Future<int> countReviews({
    required DateTime start,
    required DateTime end,
  }) async {
    final expression = flashcardReviewLogs.id.count();
    final query = selectOnly(flashcardReviewLogs)
      ..addColumns([expression])
      ..where(flashcardReviewLogs.reviewedAt.isBiggerOrEqualValue(start) &
          flashcardReviewLogs.reviewedAt.isSmallerThanValue(end));
    return (await query.getSingle()).read(expression) ?? 0;
  }

  Future<List<Flashcard>> getAllCards() => select(flashcards).get();

  Future<void> addAllCards(List<Flashcard> cards) => batch((batch) {
        batch.insertAllOnConflictUpdate(flashcards, cards);
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

  Future<List<String>> _activeWords({int? tag}) async {
    final query = select(wordbook);
    if (tag != null) query.where((row) => row.tag.equals(tag));
    return (await query.get()).map((row) => row.word).toSet().toList();
  }
}

@DriftAccessor(tables: [Wordbook])
class WordbookDao extends DatabaseAccessor<AppDatabase>
    with _$WordbookDaoMixin {
  WordbookDao(super.attachedDatabase);

  Future<void> addAllWords(List<WordbookData> data) async {
    final existing = await getAllWords();
    final existingSet = existing.map((e) => "${e.word}_${e.tag}").toSet();

    final toInsert =
        data.where((e) => !existingSet.contains("${e.word}_${e.tag}")).toList();

    if (toInsert.isNotEmpty) {
      await batch((batch) {
        batch.insertAll(wordbook, toInsert);
      });
    }
  }

  Future<int> countTotalWords() async {
    final count = countAll();
    final query = selectOnly(wordbook)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<int> addWord(String word, {int? tag}) {
    return into(wordbook).insert(WordbookCompanion(
        tag: Value(tag), word: Value(word), createdAt: Value(DateTime.now())));
  }

  Future<List<WordbookData>> getAllWords() {
    return (select(wordbook)).get();
  }

  Future<List<WordbookData>> getAllWordsWithTag(
      {int? tag, bool skipTagged = false}) {
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

  Future<List<WordbookData>> searchWords(String query) {
    return (select(wordbook)
          ..where((t) => t.word.like("$query%"))
          ..limit(40))
        .get();
  }

  Future<int> removeWord(String word, {int? tag}) {
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

  Future<void> removeWords(List<WordbookData> words) async {
    await batch((batch) {
      for (final wordData in words) {
        if (wordData.tag == null) {
          batch.deleteWhere(wordbook,
              (row) => row.word.isValue(wordData.word) & row.tag.isNull());
        } else {
          batch.deleteWhere(
              wordbook,
              (row) =>
                  row.word.isValue(wordData.word) &
                  row.tag.isValue(wordData.tag!));
        }
      }
    });
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

  Future<Set<String>> wordsExist(Iterable<String> words) async {
    final result =
        await (select(wordbook)..where((u) => u.word.isIn(words))).get();
    return result.map((e) => e.word).toSet();
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

  Future<List<MddAudioResourceData>?> getByKeyAndMddAudioID(
      String key, int mddAudioId) async {
    return (await (select(mddAudioResource)
          ..where(
              (t) => t.key.isValue(key) & t.mddAudioListId.isValue(mddAudioId)))
        .get());
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
    return (select(aiExplanations)..where((t) => t.word.isValue(word)))
        .getSingleOrNull();
  }

  Future<int> updateAiExplanation(AiExplanation explanation) {
    return (update(aiExplanations)
          ..where((t) => t.word.isValue(explanation.word)))
        .write(AiExplanationsCompanion(
      word: Value(explanation.word),
      explanation: Value(explanation.explanation),
    ));
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
    final existing = await getAllHistory();
    final existingSet = existing
        .map((e) =>
            "${e.inputText}_${e.outputText}_${e.createdAt.millisecondsSinceEpoch}")
        .toSet();

    final toInsert = data.where((e) {
      final key =
          "${e.inputText}_${e.outputText}_${e.createdAt.millisecondsSinceEpoch}";
      return !existingSet.contains(key);
    }).toList();

    if (toInsert.isNotEmpty) {
      await batch((batch) {
        batch.insertAll(writingCheckHistory, toInsert);
      });
    }
  }

  Future<List<WritingCheckHistoryData>> getAllHistory() {
    return (select(writingCheckHistory)
          ..orderBy(
              [(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
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

  Future<int> addHistory(String inputText) async {
    await deleteHistoryByInputText(inputText);
    return into(translateHistory).insert(
      TranslateHistoryCompanion(
        inputText: Value(inputText),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> addAllHistory(List<TranslateHistoryData> data) async {
    final existing = await getAllHistory();
    final existingSet = existing.map((e) => e.inputText).toSet();

    final toInsert =
        data.where((e) => !existingSet.contains(e.inputText)).toList();

    if (toInsert.isNotEmpty) {
      await batch((batch) {
        batch.insertAll(translateHistory, toInsert);
      });
    }
  }

  Future<List<TranslateHistoryData>> getAllHistory() {
    return (select(translateHistory)
          ..orderBy(
              [(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
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
    return (delete(translateHistory)
          ..where((t) => t.inputText.isValue(inputText)))
        .go();
  }
}

@DriftAccessor(tables: [OpenRecords])
class OpenRecordsDao extends DatabaseAccessor<AppDatabase>
    with _$OpenRecordsDaoMixin {
  OpenRecordsDao(super.attachedDatabase);

  Future<void> add(String word) async {
    await into(openRecords).insert(OpenRecordsCompanion(
      word: Value(word),
      createdAt: Value(DateTime.now()),
    ));
  }

  Future<List<OpenRecord>> getAll() {
    return select(openRecords).get();
  }
}

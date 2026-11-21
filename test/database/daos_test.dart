import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:drift/drift.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late AppDatabase database;
  late WordbookDao wordbookDao;
  late OpenRecordsDao openRecordsDao;
  late TranslateHistoryDao translateHistoryDao;
  late WritingCheckHistoryDao writingCheckHistoryDao;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    wordbookDao = WordbookDao(database);
    openRecordsDao = OpenRecordsDao(database);
    translateHistoryDao = TranslateHistoryDao(database);
    writingCheckHistoryDao = WritingCheckHistoryDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  group("WordbookDao", () {
    test("countWordsByDay groups by local day", () async {
      await wordbookDao.addWord("apple");
      await wordbookDao.addWord("banana");

      final counts = await wordbookDao.countWordsByDay();

      // Both words were just added, so they must land in today's *local*
      // day bucket (SQL used to group by UTC day, misfiling 00:00–08:00
      // entries for UTC+8 users).
      final now = DateTime.now();
      final today = DateTime.utc(now.year, now.month, now.day);
      expect(counts.length, 1);
      expect(counts[today], 2);
    });

    test("addAllWords should avoid duplicates based on word and tag", () async {
      await wordbookDao.addWord("apple", tag: 1);

      final now = DateTime.now();
      final newWords = [
        // Duplicate: same word and tag (should be skipped)
        WordbookData(word: "apple", tag: 1, createdAt: now),
        // New: same word but different tag (should be inserted)
        WordbookData(word: "apple", tag: 2, createdAt: now),
        // New: different word (should be inserted)
        WordbookData(word: "banana", tag: 1, createdAt: now),
      ];

      await wordbookDao.addAllWords(newWords);

      final allWords = await wordbookDao.getAllWords();

      expect(allWords.length, 3);

      expect(allWords.where((w) => w.word == "apple" && w.tag == 1).length, 1);

      expect(allWords.where((w) => w.word == "apple" && w.tag == 2).length, 1);
      expect(allWords.where((w) => w.word == "banana").length, 1);
    });
  });

  group("OpenRecordsDao", () {
    test("countByDay groups by local day", () async {
      await openRecordsDao.add("apple");
      await openRecordsDao.add("banana");

      final counts = await openRecordsDao.countByDay();

      // Same local-day bucketing contract as WordbookDao.countWordsByDay.
      final now = DateTime.now();
      final today = DateTime.utc(now.year, now.month, now.day);
      expect(counts.length, 1);
      expect(counts[today], 2);
    });
  });

  group("TranslateHistoryDao", () {
    test("addAllHistory should avoid duplicates based on inputText", () async {
      await translateHistoryDao.addHistory("hello");

      final now = DateTime.now();
      final newHistory = [
        // Duplicate: same inputText (should be skipped)
        TranslateHistoryData(id: 100, inputText: "hello", createdAt: now),
        // New: different inputText (should be inserted)
        TranslateHistoryData(id: 101, inputText: "world", createdAt: now),
      ];

      await translateHistoryDao.addAllHistory(newHistory);

      final allHistory = await translateHistoryDao.getAllHistory();

      expect(allHistory.length, 2);
      expect(
        allHistory.map((e) => e.inputText),
        containsAll(["hello", "world"]),
      );
    });
  });

  group("WritingCheckHistoryDao", () {
    test("addAllHistory should avoid duplicates based on content matches", () async {
      final now = DateTime.fromMillisecondsSinceEpoch(1000000);

      await database
          .into(database.writingCheckHistory)
          .insert(
            WritingCheckHistoryCompanion(
              inputText: Value("input1"),
              outputText: Value("output1"),
              createdAt: Value(now),
            ),
          );

      final newHistory = [
        // Duplicate: Exact match on input, output, and time (should be skipped)
        WritingCheckHistoryData(
          id: 100,
          inputText: "input1",
          outputText: "output1",
          createdAt: now,
        ),
        // New: Different output (should be inserted)
        WritingCheckHistoryData(
          id: 101,
          inputText: "input1",
          outputText: "output2",
          createdAt: now,
        ),
        // New: Different time (should be inserted)
        WritingCheckHistoryData(
          id: 102,
          inputText: "input1",
          outputText: "output1",
          createdAt: now.add(const Duration(seconds: 1)),
        ),
      ];

      await writingCheckHistoryDao.addAllHistory(newHistory);

      final allHistory = await writingCheckHistoryDao.getAllHistory();

      expect(allHistory.length, 3);

      final originalContentCount = allHistory
          .where(
            (e) =>
                e.inputText == "input1" &&
                e.outputText == "output1" &&
                e.createdAt.millisecondsSinceEpoch ==
                    now.millisecondsSinceEpoch,
          )
          .length;

      expect(
        originalContentCount,
        1,
        reason: "Should satisfy exact match deduplication",
      );
    });
  });

  group("Unicode NFC normalisation", () {
    const nfcWord = "ingl\u00E9s";
    const nfdWord = "ingle\u0301s";

    test("history keeps one row for the NFC and NFD spellings", () async {
      final historyDao = HistoryDao(database);

      await historyDao.addHistory(nfdWord);
      await historyDao.addHistory(nfcWord);
      await historyDao.addHistory(nfdWord);

      final rows = await historyDao.getAllHistory();
      expect(rows, hasLength(1));
      expect(rows.single.word, nfcWord);
    });

    test("wordbook stores and finds the NFC spelling only", () async {
      await wordbookDao.addWord(nfdWord);

      final rows = await wordbookDao.getAllWords();
      expect(rows, hasLength(1));
      expect(rows.single.word, nfcWord);

      expect(await wordbookDao.wordExist(nfcWord), isTrue);
      expect(await wordbookDao.wordExist(nfdWord), isTrue);
      expect(await wordbookDao.wordsExist([nfdWord]), {nfcWord});

      await wordbookDao.removeWord(nfdWord);
      expect(await wordbookDao.wordExist(nfcWord), isFalse);
    });
  });

  group("PersonalDictionaryDao foreign keys (P2-2)", () {
    test("enforcement is on, violations fail, deletes cascade", () async {
      final listDao = DictionaryListDao(database);
      final dao = PersonalDictionaryDao(database);

      final foreignKeys = await database
          .customSelect("PRAGMA foreign_keys")
          .getSingle();
      expect(foreignKeys.read<bool>("foreign_keys"), isTrue);

      final id = await listDao.add("personal:1", "Words", type: 4);
      final now = DateTime.now();
      final articleId = await dao.insertArticle(
        PersonalArticlesCompanion(
          dictionaryId: Value(id),
          body: Value("a fruit"),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await dao.insertHeadwords([
        PersonalHeadwordsCompanion(
          dictionaryId: Value(id),
          articleId: Value(articleId),
          headword: Value("apple"),
          normalizedHeadword: Value("apple"),
        ),
      ]);

      // A headword for a dictionary that does not exist is rejected.
      await expectLater(
        dao.insertHeadwords([
          PersonalHeadwordsCompanion(
            dictionaryId: const Value(99999),
            articleId: Value(articleId),
            headword: const Value("ghost"),
            normalizedHeadword: const Value("ghost"),
          ),
        ]),
        throwsA(isA<Object>()),
      );
      // A headword for an article that does not exist is rejected too.
      await expectLater(
        dao.insertHeadwords([
          PersonalHeadwordsCompanion(
            dictionaryId: Value(id),
            articleId: const Value(99999),
            headword: const Value("ghost"),
            normalizedHeadword: const Value("ghost"),
          ),
        ]),
        throwsA(isA<Object>()),
      );

      // Deleting the list row directly — bypassing the service — no
      // longer orphans the dictionary's rows: the cascade removes them.
      await listDao.removeById(id);
      expect(await dao.countArticles(id), 0);
      expect(await dao.countHeadwords(id), 0);

      // The per-dictionary index exists on the articles table.
      final indexes = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND tbl_name = 'personal_articles'",
          )
          .get();
      expect(
        indexes.map((row) => row.read<String>("name")),
        contains("idx_personal_articles_dictionary"),
      );
    });
  });
}

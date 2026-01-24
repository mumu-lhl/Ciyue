import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:drift/drift.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late AppDatabase database;
  late WordbookDao wordbookDao;
  late TranslateHistoryDao translateHistoryDao;
  late WritingCheckHistoryDao writingCheckHistoryDao;

  setUp(() {
    // Use an in-memory database for testing
    database = AppDatabase(NativeDatabase.memory());
    wordbookDao = WordbookDao(database);
    translateHistoryDao = TranslateHistoryDao(database);
    writingCheckHistoryDao = WritingCheckHistoryDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  group("WordbookDao", () {
    test("addAllWords should avoid duplicates based on word and tag", () async {
      // 1. Insert an initial record
      await wordbookDao.addWord("apple", tag: 1);

      final now = DateTime.now();
      // 2. Prepare import data
      final newWords = [
        // Duplicate: same word and tag (should be skipped)
        WordbookData(word: "apple", tag: 1, createdAt: now),
        // New: same word but different tag (should be inserted)
        WordbookData(word: "apple", tag: 2, createdAt: now),
        // New: different word (should be inserted)
        WordbookData(word: "banana", tag: 1, createdAt: now),
      ];

      // 3. Perform batch add
      await wordbookDao.addAllWords(newWords);

      // 4. Verify results
      final allWords = await wordbookDao.getAllWords();

      // We expect 3 records total:
      // 1. original 'apple' (tag 1)
      // 2. 'apple' (tag 2)
      // 3. 'banana' (tag 1)
      expect(allWords.length, 3);

      // Verify duplicate was not added (count remains 1 for apple/tag:1)
      expect(allWords.where((w) => w.word == "apple" && w.tag == 1).length, 1);

      // Verify new records were added
      expect(allWords.where((w) => w.word == "apple" && w.tag == 2).length, 1);
      expect(allWords.where((w) => w.word == "banana").length, 1);
    });
  });

  group("TranslateHistoryDao", () {
    test("addAllHistory should avoid duplicates based on inputText", () async {
      // 1. Insert an initial record
      await translateHistoryDao.addHistory("hello");

      final now = DateTime.now();
      // 2. Prepare import data
      final newHistory = [
        // Duplicate: same inputText (should be skipped)
        TranslateHistoryData(id: 100, inputText: "hello", createdAt: now),
        // New: different inputText (should be inserted)
        TranslateHistoryData(id: 101, inputText: "world", createdAt: now),
      ];

      // 3. Perform batch add
      await translateHistoryDao.addAllHistory(newHistory);

      // 4. Verify results
      final allHistory = await translateHistoryDao.getAllHistory();

      // Expect 2 records: 'hello' and 'world'
      expect(allHistory.length, 2);
      expect(
          allHistory.map((e) => e.inputText), containsAll(["hello", "world"]));
    });
  });

  group("WritingCheckHistoryDao", () {
    test("addAllHistory should avoid duplicates based on content matches",
        () async {
      final now = DateTime.fromMillisecondsSinceEpoch(1000000);

      // 1. Insert an initial record directly to set specific fields
      await database
          .into(database.writingCheckHistory)
          .insert(WritingCheckHistoryCompanion(
            inputText: Value("input1"),
            outputText: Value("output1"),
            createdAt: Value(now),
          ));

      // 2. Prepare import data
      final newHistory = [
        // Duplicate: Exact match on input, output, and time (should be skipped)
        WritingCheckHistoryData(
            id: 100,
            inputText: "input1",
            outputText: "output1",
            createdAt: now),
        // New: Different output (should be inserted)
        WritingCheckHistoryData(
            id: 101,
            inputText: "input1",
            outputText: "output2",
            createdAt: now),
        // New: Different time (should be inserted)
        WritingCheckHistoryData(
            id: 102,
            inputText: "input1",
            outputText: "output1",
            createdAt: now.add(const Duration(seconds: 1))),
      ];

      // 3. Perform batch add
      await writingCheckHistoryDao.addAllHistory(newHistory);

      // 4. Verify results
      final allHistory = await writingCheckHistoryDao.getAllHistory();

      // Expect 3 records:
      // 1. Original
      // 2. Different output
      // 3. Different time
      // The exact duplicate should be skipped.
      expect(allHistory.length, 3);

      // Verify the duplicate logic by counting entries with original content
      final originalContentCount = allHistory
          .where((e) =>
              e.inputText == "input1" &&
              e.outputText == "output1" &&
              e.createdAt.millisecondsSinceEpoch == now.millisecondsSinceEpoch)
          .length;

      expect(originalContentCount, 1,
          reason: "Should satisfy exact match deduplication");
    });
  });
}

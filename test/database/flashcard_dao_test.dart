import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late AppDatabase database;
  late WordbookDao wordbookDao;
  late FlashcardDao flashcardDao;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    wordbookDao = WordbookDao(database);
    flashcardDao = FlashcardDao(database);
  });

  tearDown(() => database.close());

  test("new words are unique across tags and respect selected tag", () async {
    await wordbookDao.addWord("apple", tag: 1);
    await wordbookDao.addWord("apple", tag: 2);
    await wordbookDao.addWord("banana", tag: 2);

    expect(await flashcardDao.getNewWords(limit: 20), ["apple", "banana"]);
    expect(await flashcardDao.getNewWords(limit: 20, tag: 1), ["apple"]);
  });

  test("due cards exclude removed words but keep stored progress", () async {
    final now = DateTime.utc(2026, 7, 11, 8);
    await wordbookDao.addWord("apple");
    await flashcardDao.putCard(
      word: "apple",
      state: 1,
      due: now.subtract(const Duration(minutes: 1)),
      introducedAt: now.subtract(const Duration(days: 1)),
    );

    expect(await flashcardDao.getDueCards(now: now), hasLength(1));
    await wordbookDao.removeWord("apple");
    expect(await flashcardDao.getDueCards(now: now), isEmpty);
    expect(await flashcardDao.getCard("apple"), isNotNull);
  });

  test("introduced today consumes the daily new-card allowance", () async {
    final start = DateTime.utc(2026, 7, 11);
    await wordbookDao.addWord("apple");
    await flashcardDao.putCard(
      word: "apple",
      state: 0,
      due: start,
      introducedAt: start.add(const Duration(hours: 2)),
    );

    expect(
      await flashcardDao.countIntroduced(
        start: start,
        end: start.add(const Duration(days: 1)),
      ),
      1,
    );
  });

  test("counts reviews inside the local-day UTC window", () async {
    final start = DateTime.utc(2026, 7, 11);
    await flashcardDao.addReviewLog(
      word: "old",
      rating: 2,
      reviewedAt: start.subtract(const Duration(seconds: 1)),
    );
    await flashcardDao.addReviewLog(
      word: "today",
      rating: 2,
      reviewedAt: start.add(const Duration(hours: 1)),
    );

    expect(
      await flashcardDao.countReviews(
        start: start,
        end: start.add(const Duration(days: 1)),
      ),
      1,
    );
  });
}

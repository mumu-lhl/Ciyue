import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/services/flashcard_scheduler.dart";
import "package:ciyue/services/flashcard_study_service.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late AppDatabase database;
  late WordbookDao wordbookDao;
  late FlashcardDao flashcardDao;
  late FlashcardStudyService service;
  final now = DateTime.utc(2026, 7, 11, 8);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    wordbookDao = WordbookDao(database);
    flashcardDao = FlashcardDao(database);
    service = FlashcardStudyService(
      dao: flashcardDao,
      scheduler: FlashcardScheduler(enableFuzzing: false),
    );
  });

  tearDown(() => database.close());

  test("session contains due cards before limited new cards", () async {
    await wordbookDao.addWord("due");
    await wordbookDao.addWord("new one");
    await wordbookDao.addWord("new two");
    await flashcardDao.putCard(
      word: "due",
      state: 1,
      due: now.subtract(const Duration(days: 1)),
      introducedAt: now.subtract(const Duration(days: 10)),
    );

    final session = await service.loadSession(
      now: now,
      localDayStartUtc: DateTime.utc(2026, 7, 11),
      dailyNewLimit: 1,
    );

    expect(session.map((item) => item.word), ["due", "new one"]);
    expect(await flashcardDao.getCard("new one"), isNotNull);
    expect(await flashcardDao.getCard("new two"), isNull);
  });

  test("rating writes log and undo restores previous card", () async {
    await wordbookDao.addWord("apple");
    final session = await service.loadSession(
      now: now,
      localDayStartUtc: DateTime.utc(2026, 7, 11),
      dailyNewLimit: 20,
    );
    final before = await flashcardDao.getCard("apple");

    final undo = await service.rate(
      session.single,
      FlashcardRating.good,
      now: now,
      durationMs: 900,
    );

    expect((await flashcardDao.getReviewLogs()).single.rating, 2);
    expect((await flashcardDao.getCard("apple"))!.lastReview!.toUtc(), now);

    await service.undo(undo);
    expect(await flashcardDao.getReviewLogs(), isEmpty);
    expect(await flashcardDao.getCard("apple"), before);
  });
}

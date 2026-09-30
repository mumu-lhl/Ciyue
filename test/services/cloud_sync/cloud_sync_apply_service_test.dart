import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/backup/backup.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:ciyue/services/cloud_sync/apply_service.dart";
import "package:ciyue/services/cloud_sync/snapshot_builder.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late AppDatabase database;
  late CloudSyncApplyService service;
  const builder = CloudSyncSnapshotBuilder();
  final now = DateTime.utc(2026, 3, 1);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    service = CloudSyncApplyService(database: database);
  });

  tearDown(() => database.close());

  test(
    "applies merged wordbook, tags, cards, and review logs atomically",
    () async {
      await database
          .into(database.wordbookTags)
          .insert(WordbookTag(id: 42, tag: "Fruit"));
      await database.wordbookDao.addWord("old word");

      final snapshot = builder.capture(
        data: BackupData(
          version: 2,
          wordbookWords: [WordbookData(word: "apple", tag: 7, createdAt: now)],
          wordbookTags: [WordbookTag(id: 7, tag: "Fruit")],
          flashcards: [
            Flashcard(
              word: "apple",
              state: 2,
              due: now.add(const Duration(days: 2)),
              lastReview: now,
              introducedAt: now.subtract(const Duration(days: 1)),
            ),
          ],
          flashcardReviewLogs: [
            FlashcardReviewLog(
              id: 15,
              word: "apple",
              rating: 2,
              reviewedAt: now,
              durationMs: 700,
            ),
          ],
        ),
        spaceId: "space",
        deviceId: "device",
      );

      await service.apply(snapshot);

      final words = await database.wordbookDao.getAllWords();
      expect(words.map((word) => word.word), ["apple"]);
      expect(words.single.tag, 42);
      expect((await database.wordbookTagsDao.getAllTags()).single.id, 42);
      expect((await database.flashcardDao.getAllCards()).single.state, 2);
      expect((await database.flashcardDao.getReviewLogs()).single.rating, 2);
    },
  );

  test("refuses conflicting cloud state without changing local data", () async {
    await database.wordbookDao.addWord("keep local");
    final base = SyncRecord(
      entityType: "wordbook-entry",
      entityId: "entry",
      versionId: "base",
      parentVersionIds: const [],
      modifiedAt: now,
      data: {
        "word": "apple",
        "tagName": null,
        "createdAt": now.toIso8601String(),
      },
      deleted: false,
    );
    final snapshot = SyncSnapshot(
      spaceId: "space",
      deviceId: "device",
      records: [
        base,
        SyncRecord(
          entityType: "wordbook-entry",
          entityId: "entry",
          versionId: "local",
          parentVersionIds: const ["base"],
          modifiedAt: now.add(const Duration(seconds: 1)),
          data: {
            "word": "apple",
            "tagName": null,
            "createdAt": now.toIso8601String(),
            "note": "local",
          },
          deleted: false,
        ),
        SyncRecord(
          entityType: "wordbook-entry",
          entityId: "entry",
          versionId: "remote",
          parentVersionIds: const ["base"],
          modifiedAt: now.add(const Duration(seconds: 1)),
          data: {
            "word": "apple",
            "tagName": null,
            "createdAt": now.toIso8601String(),
            "note": "remote",
          },
          deleted: false,
        ),
      ],
    );

    await expectLater(service.apply(snapshot), throwsStateError);
    expect(
      (await database.wordbookDao.getAllWords()).map((word) => word.word),
      ["keep local"],
    );
  });
}

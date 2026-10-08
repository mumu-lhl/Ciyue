import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/backup/backup.dart";
import "package:ciyue/services/cloud_sync/backup_codec.dart";
import "package:ciyue/services/cloud_sync/snapshot_builder.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  const builder = CloudSyncSnapshotBuilder();
  const codec = CloudSyncBackupCodec();
  final addedAt = DateTime.utc(2026, 2, 3);

  BackupData backup({
    List<WordbookData> words = const [],
    List<WordbookTag> tags = const [],
    List<Flashcard> cards = const [],
    List<FlashcardReviewLog> logs = const [],
  }) => BackupData(
    version: 2,
    wordbookWords: words,
    wordbookTags: tags,
    flashcards: cards,
    flashcardReviewLogs: logs,
  );

  test("rebuilds local tag IDs and restores vocabulary and FSRS state", () {
    final localData = backup(
      words: [WordbookData(word: "apple", tag: 42, createdAt: addedAt)],
      tags: [WordbookTag(id: 42, tag: "Fruit")],
      cards: [
        Flashcard(
          word: "apple",
          state: 2,
          step: 1,
          stability: 2.5,
          difficulty: 4.3,
          due: DateTime.utc(2026, 2, 5),
          lastReview: DateTime.utc(2026, 2, 4),
          introducedAt: addedAt,
        ),
      ],
      logs: [
        FlashcardReviewLog(
          id: 900,
          word: "apple",
          rating: 2,
          reviewedAt: DateTime.utc(2026, 2, 4),
          durationMs: 500,
        ),
      ],
    );
    final snapshot = builder.capture(
      data: localData,
      spaceId: "space",
      deviceId: "device",
    );

    final restored = codec.decode(snapshot);

    expect(restored.wordbookTags, [WordbookTag(id: 1, tag: "Fruit")]);
    expect(restored.wordbookWords.single.word, "apple");
    expect(restored.wordbookWords.single.tag, 1);
    expect(restored.wordbookWords.single.createdAt.toUtc(), addedAt);
    expect(restored.flashcards.single.state, 2);
    expect(restored.flashcards.single.due.toUtc(), DateTime.utc(2026, 2, 5));
    expect(restored.flashcardReviewLogs.single.rating, 2);
    expect(restored.flashcardReviewLogs.single.durationMs, 500);
  });

  test("preserves existing local IDs for tags that are already present", () {
    final snapshot = builder.capture(
      data: backup(
        words: [WordbookData(word: "apple", tag: 42, createdAt: addedAt)],
        tags: [WordbookTag(id: 42, tag: "Fruit")],
      ),
      spaceId: "space",
      deviceId: "device",
    );

    final restored = codec.decode(
      snapshot,
      localTags: [WordbookTag(id: 42, tag: "Fruit")],
    );

    expect(restored.wordbookWords.single.tag, 42);
  });

  test("does not restore deleted entries or deleted tags", () {
    final initial = builder.capture(
      data: backup(
        words: [WordbookData(word: "apple", tag: 42, createdAt: addedAt)],
        tags: [WordbookTag(id: 42, tag: "Fruit")],
      ),
      spaceId: "space",
      deviceId: "device",
    );
    final afterDelete = builder.capture(
      data: backup(),
      spaceId: "space",
      deviceId: "device",
      previous: initial,
    );

    final restored = codec.decode(afterDelete);

    expect(restored.wordbookWords, isEmpty);
    expect(restored.wordbookTags, isEmpty);
  });

  test("refuses to apply snapshots with unresolved concurrent edits", () {
    final base = SyncRecord(
      entityType: "wordbook-entry",
      entityId: "entry",
      versionId: "base",
      parentVersionIds: const [],
      modifiedAt: addedAt,
      data: {
        "word": "apple",
        "tagName": null,
        "createdAt": addedAt.toIso8601String(),
      },
      deleted: false,
    );
    final local = SyncRecord(
      entityType: "wordbook-entry",
      entityId: "entry",
      versionId: "local",
      parentVersionIds: const ["base"],
      modifiedAt: addedAt.add(const Duration(seconds: 1)),
      data: {
        "word": "apple",
        "tagName": null,
        "createdAt": addedAt.toIso8601String(),
        "note": "local",
      },
      deleted: false,
    );
    final remote = SyncRecord(
      entityType: "wordbook-entry",
      entityId: "entry",
      versionId: "remote",
      parentVersionIds: const ["base"],
      modifiedAt: addedAt.add(const Duration(seconds: 1)),
      data: {
        "word": "apple",
        "tagName": null,
        "createdAt": addedAt.toIso8601String(),
        "note": "remote",
      },
      deleted: false,
    );
    final snapshot = SyncSnapshot(
      spaceId: "space",
      deviceId: "device",
      records: [base, local, remote],
    );

    expect(() => codec.decode(snapshot), throwsStateError);

    final restored = codec.decode(snapshot, allowAutoResolve: true);
    expect(restored.wordbookWords.single.word, "apple");
  });
}

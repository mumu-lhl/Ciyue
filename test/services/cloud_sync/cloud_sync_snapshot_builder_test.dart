import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/backup/backup.dart";
import "package:ciyue/services/cloud_sync/snapshot_builder.dart";
import "package:drift/drift.dart" show Value;
import "package:flutter_test/flutter_test.dart";

void main() {
  const spaceId = "space-1";
  const deviceId = "device-1";
  final builder = CloudSyncSnapshotBuilder();
  final addedAt = DateTime.utc(2026, 1, 1);

  BackupData data({
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

  test("captures wordbook entries by tag name, plus tags and review data", () {
    final snapshot = builder.capture(
      data: data(
        words: [WordbookData(word: "apple", tag: 7, createdAt: addedAt)],
        tags: [WordbookTag(id: 7, tag: "Fruit")],
        cards: [
          Flashcard(
            word: "apple",
            state: 2,
            step: 1,
            stability: 3.2,
            difficulty: 4.1,
            due: DateTime.utc(2026, 1, 2),
            lastReview: DateTime.utc(2026, 1, 1, 1),
            introducedAt: addedAt,
          ),
        ],
        logs: [
          FlashcardReviewLog(
            id: 99,
            word: "apple",
            rating: 2,
            reviewedAt: DateTime.utc(2026, 1, 1, 1),
            durationMs: 850,
          ),
        ],
      ),
      spaceId: spaceId,
      deviceId: deviceId,
    );

    expect(snapshot.records.map((record) => record.entityType).toSet(), {
      "wordbook-tag",
      "wordbook-entry",
      "flashcard",
      "flashcard-review-log",
    });
    final entry = snapshot.records.singleWhere(
      (record) => record.entityType == "wordbook-entry",
    );
    expect(entry.data, {
      "word": "apple",
      "tagName": "Fruit",
      "createdAt": addedAt.toIso8601String(),
    });
    expect(entry.entityId, isNot("7"));
    expect(
      snapshot.records
          .singleWhere((r) => r.entityType == "flashcard")
          .data?["state"],
      2,
    );
  });

  test("deduplicates repeated wordbook rows using their earliest add date", () {
    final snapshot = builder.capture(
      data: data(
        words: [
          WordbookData(
            word: "apple",
            createdAt: addedAt.add(const Duration(days: 2)),
          ),
          WordbookData(word: "apple", createdAt: addedAt),
        ],
      ),
      spaceId: spaceId,
      deviceId: deviceId,
    );

    expect(
      snapshot.records.where((r) => r.entityType == "wordbook-entry"),
      hasLength(1),
    );
    expect(
      snapshot.records
          .singleWhere((r) => r.entityType == "wordbook-entry")
          .data?["createdAt"],
      addedAt.toIso8601String(),
    );
  });

  test("unchanged local data reuses the previous versions", () {
    final backup = data(
      words: [WordbookData(word: "apple", createdAt: addedAt)],
    );
    final first = builder.capture(
      data: backup,
      spaceId: spaceId,
      deviceId: deviceId,
    );
    final second = builder.capture(
      data: backup,
      spaceId: spaceId,
      deviceId: deviceId,
      previous: first,
    );

    expect(second.records, hasLength(first.records.length));
    expect(
      second.records.map((record) => record.versionId),
      first.records.map((record) => record.versionId),
    );
  });

  test("removing a saved word creates a tombstone version", () {
    final first = builder.capture(
      data: data(
        words: [WordbookData(word: "apple", createdAt: addedAt)],
      ),
      spaceId: spaceId,
      deviceId: deviceId,
    );
    final second = builder.capture(
      data: data(),
      spaceId: spaceId,
      deviceId: deviceId,
      previous: first,
    );

    final wordVersions = second.records
        .where((record) => record.entityType == "wordbook-entry")
        .toList();
    expect(wordVersions, hasLength(2));
    expect(wordVersions.last.deleted, isTrue);
    expect(wordVersions.last.parentVersionIds, [wordVersions.first.versionId]);
  });

  test("updates flashcard progress as a child revision", () {
    final initial = Flashcard(
      word: "apple",
      state: 1,
      due: addedAt,
      introducedAt: addedAt,
    );
    final reviewed = initial.copyWith(
      state: 2,
      due: DateTime.utc(2026, 1, 3),
      lastReview: Value(DateTime.utc(2026, 1, 2)),
    );
    final first = builder.capture(
      data: data(cards: [initial]),
      spaceId: spaceId,
      deviceId: deviceId,
    );
    final second = builder.capture(
      data: data(cards: [reviewed]),
      spaceId: spaceId,
      deviceId: deviceId,
      previous: first,
    );

    final versions = second.records
        .where((record) => record.entityType == "flashcard")
        .toList();
    expect(versions, hasLength(2));
    expect(versions.last.parentVersionIds, [versions.first.versionId]);
    expect(versions.last.data?["state"], 2);
  });

  test("rejects a wordbook row whose tag ID has no saved tag", () {
    expect(
      () => builder.capture(
        data: data(
          words: [WordbookData(word: "apple", tag: 404, createdAt: addedAt)],
        ),
        spaceId: spaceId,
        deviceId: deviceId,
      ),
      throwsFormatException,
    );
  });
}

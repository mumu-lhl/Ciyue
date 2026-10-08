import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  const engine = CloudSyncEngine();

  SyncRecord record({
    required String id,
    required String versionId,
    required Map<String, Object?> data,
    List<String> parents = const [],
    String type = "wordbook-entry",
    bool deleted = false,
    DateTime? modifiedAt,
  }) => SyncRecord(
    entityType: type,
    entityId: id,
    versionId: versionId,
    parentVersionIds: parents,
    modifiedAt: modifiedAt ?? DateTime.utc(2026, 1, 1),
    data: deleted ? null : data,
    deleted: deleted,
  );

  SyncSnapshot snapshot({
    String spaceId = "space-1",
    String deviceId = "device-1",
    List<SyncRecord> records = const [],
  }) => SyncSnapshot(spaceId: spaceId, deviceId: deviceId, records: records);

  test(
    "merges additions and deduplicates versions already on both devices",
    () {
      final shared = record(id: "apple", versionId: "v1", data: {"tag": "A"});
      final localOnly = record(id: "book", versionId: "v2", data: {"tag": "B"});
      final remoteOnly = record(
        id: "pear",
        versionId: "v3",
        data: {"tag": "A"},
        type: "wordbook-entry",
      );

      final result = engine.merge(
        snapshot(records: [shared, localOnly]),
        snapshot(deviceId: "device-2", records: [shared, remoteOnly]),
      );

      expect(
        result.snapshot.records,
        containsAll([shared, localOnly, remoteOnly]),
      );
      expect(result.snapshot.records, hasLength(3));
      expect(result.conflicts, isEmpty);
    },
  );

  test("identical versions deduplicate independent of JSON map key order", () {
    final local = record(
      id: "apple",
      versionId: "v1",
      data: {"word": "apple", "note": "fruit"},
    );
    final remote = record(
      id: "apple",
      versionId: "v1",
      data: {"note": "fruit", "word": "apple"},
    );

    final result = engine.merge(
      snapshot(records: [local]),
      snapshot(deviceId: "device-2", records: [remote]),
    );

    expect(result.snapshot.records, hasLength(1));
    expect(result.conflicts, isEmpty);
  });

  test("a sequential edit supersedes its parent without conflict", () {
    final original = record(
      id: "apple",
      versionId: "v1",
      data: {"note": "first"},
    );
    final updated = record(
      id: "apple",
      versionId: "v2",
      parents: ["v1"],
      data: {"note": "edited"},
    );

    final result = engine.merge(
      snapshot(records: [original]),
      snapshot(deviceId: "device-2", records: [original, updated]),
    );

    expect(result.conflicts, isEmpty);
    expect(result.snapshot.latestRecords.single.versionId, "v2");
  });

  test("concurrent edits are preserved and surfaced as a conflict", () {
    final original = record(
      id: "apple",
      versionId: "v1",
      data: {"note": "first"},
    );
    final localEdit = record(
      id: "apple",
      versionId: "v2-local",
      parents: ["v1"],
      data: {"note": "local edit"},
    );
    final remoteEdit = record(
      id: "apple",
      versionId: "v2-remote",
      parents: ["v1"],
      data: {"note": "remote edit"},
    );

    final result = engine.merge(
      snapshot(records: [original, localEdit]),
      snapshot(deviceId: "device-2", records: [original, remoteEdit]),
    );

    expect(result.snapshot.records, containsAll([localEdit, remoteEdit]));
    expect(result.conflicts, hasLength(1));
    expect(result.conflicts.single.entityId, "apple");
    expect(
      result.conflicts.single.versions.map((version) => version.versionId),
      containsAll(["v2-local", "v2-remote"]),
    );
  });

  test("concurrent deletion and edit is not silently resolved", () {
    final original = record(
      id: "apple",
      versionId: "v1",
      data: {"word": "apple"},
    );
    final deleted = record(
      id: "apple",
      versionId: "v2-delete",
      parents: ["v1"],
      data: const {},
      deleted: true,
    );
    final edited = record(
      id: "apple",
      versionId: "v2-edit",
      parents: ["v1"],
      data: {"note": "keep this"},
    );

    final result = engine.merge(
      snapshot(records: [original, deleted]),
      snapshot(deviceId: "device-2", records: [original, edited]),
    );

    expect(result.conflicts, hasLength(1));
    expect(result.conflicts.single.versions.map((v) => v.deleted), [
      true,
      false,
    ]);
  });

  test("does not merge snapshots from different sync spaces", () {
    expect(
      () => engine.merge(
        snapshot(records: []),
        snapshot(spaceId: "other-space", deviceId: "device-2"),
      ),
      throwsArgumentError,
    );
  });

  test("snapshot round-trips through JSON", () {
    final original = snapshot(
      records: [
        record(
          id: "apple",
          versionId: "v1",
          data: {"word": "apple", "createdAt": "2026-01-01T00:00:00.000Z"},
        ),
      ],
    );

    expect(
      SyncSnapshot.fromJson(original.toJson()).toJson(),
      original.toJson(),
    );
  });

  test(
    "resolveConflicts resolves concurrent edits using deterministic LWW",
    () {
      final baseTime = DateTime.utc(2026, 1, 1);
      final original = record(
        id: "apple",
        versionId: "v1",
        data: {"word": "apple"},
        modifiedAt: baseTime,
      );
      final localEdit = record(
        id: "apple",
        versionId: "v2-local",
        parents: ["v1"],
        modifiedAt: baseTime.add(const Duration(seconds: 1)),
        data: {"word": "apple", "note": "local"},
      );
      final remoteEdit = record(
        id: "apple",
        versionId: "v2-remote",
        parents: ["v1"],
        modifiedAt: baseTime.add(const Duration(seconds: 2)),
        data: {"word": "apple", "note": "remote-wins"},
      );

      final merged = engine.merge(
        snapshot(records: [original, localEdit]),
        snapshot(deviceId: "device-2", records: [original, remoteEdit]),
      );

      expect(merged.conflicts, hasLength(1));

      final resolved = engine.resolveConflicts(merged.snapshot);
      final postMerge = engine.merge(resolved, resolved);
      expect(postMerge.conflicts, isEmpty);

      final heads = resolved.latestRecords;
      expect(heads, hasLength(1));
      expect(heads.single.data?["note"], "remote-wins");
      expect(
        heads.single.parentVersionIds,
        containsAll(["v2-local", "v2-remote"]),
      );
    },
  );
}

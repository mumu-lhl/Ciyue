import "dart:io";
import "dart:typed_data";

import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:ciyue/services/cloud_sync/coordinator.dart";
import "package:dio/dio.dart" show ProgressCallback;
import "package:flutter_test/flutter_test.dart";

void main() {
  late _MemoryCloudFileStore store;
  late CloudSyncCoordinator coordinator;

  setUp(() {
    store = _MemoryCloudFileStore();
    coordinator = CloudSyncCoordinator();
  });

  SyncRecord record({
    required String version,
    required String note,
    List<String> parents = const [],
  }) => SyncRecord(
    entityType: "wordbook-entry",
    entityId: "apple",
    versionId: version,
    parentVersionIds: parents,
    modifiedAt: DateTime.utc(2026, 1, 1),
    data: {"note": note},
    deleted: false,
  );

  SyncSnapshot snapshot(String deviceId, List<SyncRecord> records) =>
      SyncSnapshot(
        spaceId: "shared-folder-id",
        deviceId: deviceId,
        records: records,
      );

  test(
    "first sync uploads a device snapshot under the selected root",
    () async {
      final local = snapshot("device-a", [
        record(version: "v1", note: "first"),
      ]);

      final result = await coordinator.sync(
        fileStore: store,
        remoteRoot: "Ciyue",
        localSnapshot: local,
      );

      expect(result.conflicts, isEmpty);
      expect(result.snapshot.records, [local.records.single]);
      expect(store.files.keys, contains("Ciyue/sync/devices/device-a.json"));
      expect(
        SyncSnapshot.decode(
          String.fromCharCodes(
            store.files["Ciyue/sync/devices/device-a.json"]!,
          ),
        ).records.single.versionId,
        "v1",
      );
    },
  );

  test(
    "new devices adopt the sync-space ID stored in the cloud folder",
    () async {
      const spaceManager = CloudSyncSpaceManager();
      final firstSpace = await spaceManager.resolve(
        fileStore: store,
        remoteRoot: "Ciyue",
        preferredSpaceId: null,
        generatedSpaceId: "space-a",
      );
      final secondSpace = await spaceManager.resolve(
        fileStore: store,
        remoteRoot: "Ciyue",
        preferredSpaceId: null,
        generatedSpaceId: "different-local-id",
      );

      expect(firstSpace, "space-a");
      expect(secondSpace, "space-a");
      expect(store.files.keys, contains("Ciyue/sync/space.json"));
    },
  );

  test("refuses to attach a local sync state to another cloud space", () async {
    const spaceManager = CloudSyncSpaceManager();
    await spaceManager.resolve(
      fileStore: store,
      remoteRoot: "Ciyue",
      preferredSpaceId: null,
      generatedSpaceId: "space-a",
    );

    await expectLater(
      spaceManager.resolve(
        fileStore: store,
        remoteRoot: "Ciyue",
        preferredSpaceId: "space-b",
        generatedSpaceId: "space-b",
      ),
      throwsStateError,
    );
  });

  test("repeat sync skips an unchanged upload", () async {
    final local = snapshot("device-a", [record(version: "v1", note: "first")]);
    await coordinator.sync(
      fileStore: store,
      remoteRoot: "Ciyue",
      localSnapshot: local,
    );

    final result = await coordinator.sync(
      fileStore: store,
      remoteRoot: "Ciyue",
      localSnapshot: local,
    );

    expect(result.uploaded, isFalse);
    expect(result.snapshot.records, hasLength(1));
  });

  test(
    "new device downloads and merges all existing device snapshots",
    () async {
      final deviceA = snapshot("device-a", [
        record(version: "v1", note: "first"),
      ]);
      final deviceB = snapshot("device-b", [
        record(version: "v1", note: "first"),
        record(version: "v2", note: "updated", parents: ["v1"]),
      ]);
      await coordinator.sync(
        fileStore: store,
        remoteRoot: "Ciyue",
        localSnapshot: deviceA,
      );

      final result = await coordinator.sync(
        fileStore: store,
        remoteRoot: "Ciyue",
        localSnapshot: snapshot("device-b", deviceB.records),
      );

      expect(result.conflicts, isEmpty);
      expect(result.snapshot.latestRecords.single.versionId, "v2");
      expect(store.files.keys, contains("Ciyue/sync/devices/device-b.json"));
      final storedB = SyncSnapshot.decode(
        String.fromCharCodes(store.files["Ciyue/sync/devices/device-b.json"]!),
      );
      expect(storedB.records.map((record) => record.versionId), ["v1", "v2"]);
    },
  );

  test("uploads conflict history without selecting a winner", () async {
    final base = record(version: "v1", note: "base");
    final local = snapshot("device-a", [
      base,
      record(version: "v2-a", note: "local", parents: ["v1"]),
    ]);
    final remote = snapshot("device-b", [
      base,
      record(version: "v2-b", note: "remote", parents: ["v1"]),
    ]);
    await coordinator.sync(
      fileStore: store,
      remoteRoot: "Ciyue",
      localSnapshot: remote,
    );

    final result = await coordinator.sync(
      fileStore: store,
      remoteRoot: "Ciyue",
      localSnapshot: local,
    );

    expect(result.conflicts, hasLength(1));
    expect(
      result.conflicts.single.versions.map((version) => version.versionId),
      containsAll(["v2-a", "v2-b"]),
    );
    expect(result.snapshot.latestRecords.map((version) => version.versionId), [
      "v2-a",
      "v2-b",
    ]);
  });
}

class _MemoryCloudFileStore implements CloudFileStore {
  final Map<String, Uint8List> files = {};
  final Set<String> directories = {};

  @override
  Future<void> ensureDirectory(String remotePath) async {
    directories.add(remotePath);
  }

  @override
  Future<List<CloudFileEntry>> listDirectory(String remotePath) async {
    final prefix = remotePath.endsWith("/") ? remotePath : "$remotePath/";
    final entries = <String, CloudFileEntry>{};
    for (final directory in directories) {
      if (!directory.startsWith(prefix)) continue;
      final remainder = directory.substring(prefix.length);
      if (remainder.isEmpty) continue;
      final name = remainder.split("/").first;
      entries[name] = CloudFileEntry(
        name: name,
        path: "$prefix$name",
        isDirectory: true,
      );
    }
    for (final path in files.keys) {
      if (!path.startsWith(prefix)) continue;
      final remainder = path.substring(prefix.length);
      if (remainder.isEmpty || remainder.contains("/")) continue;
      entries[remainder] = CloudFileEntry(
        name: remainder,
        path: "$prefix$remainder",
        isDirectory: false,
        sizeBytes: files[path]!.length,
      );
    }
    return entries.values.toList();
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    File destination, {
    ProgressCallback? onReceiveProgress,
  }) async {
    final bytes = files[remotePath];
    if (bytes == null) {
      throw FileSystemException("Remote file not found", remotePath);
    }
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes);
    onReceiveProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> uploadFile(
    String remotePath,
    File source, {
    ProgressCallback? onSendProgress,
  }) async {
    final bytes = await source.readAsBytes();
    files[remotePath] = bytes;
    onSendProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    files.remove(remotePath);
  }

  @override
  Future<void> close() async {}
}

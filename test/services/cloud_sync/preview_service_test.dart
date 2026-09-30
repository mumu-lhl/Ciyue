import "dart:io";
import "dart:typed_data";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:ciyue/services/cloud_sync/preview_service.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:dio/dio.dart" show ProgressCallback;
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late AppDatabase database;
  late _MemoryCloudFileStore cloud;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    cloud = _MemoryCloudFileStore();
  });

  tearDown(() async {
    await database.close();
  });

  test("previews local and remote data without writing to the cloud", () async {
    await database.wordbookDao.addWord("apple");
    cloud.directories.addAll(["Ciyue", "Ciyue/sync", "Ciyue/sync/devices"]);
    cloud.files["Ciyue/sync/space.json"] = Uint8List.fromList(
      '{"app":"ciyue","formatVersion":1,"spaceId":"space-1"}'.codeUnits,
    );
    cloud.files["Ciyue/sync/devices/device-b.json"] = Uint8List.fromList(
      snapshot(
        device: "device-b",
        records: [record(id: "banana", version: "banana-v1", word: "banana")],
      ).encode().codeUnits,
    );
    final before = Map<String, Uint8List>.from(cloud.files);

    final preview = await CloudSyncPreviewService(database: database).preview(
      fileStore: cloud,
      remoteRoot: "Ciyue",
      deviceId: "device-a",
      generatedSpaceId: "new-space",
    );

    expect(preview.remoteFolderExists, isTrue);
    expect(preview.spaceId, "space-1");
    expect(preview.remoteDeviceCount, 1);
    expect(preview.local.wordbookEntries, 1);
    expect(preview.remote.wordbookEntries, 1);
    expect(preview.merged.wordbookEntries, 2);
    expect(preview.conflicts, isEmpty);
    expect(cloud.files, equals(before));
    expect(cloud.createdDirectories, isEmpty);
  });

  test("previews a new folder without creating it", () async {
    final preview = await CloudSyncPreviewService(database: database).preview(
      fileStore: cloud,
      remoteRoot: "Ciyue",
      deviceId: "device-a",
      generatedSpaceId: "space-new",
    );

    expect(preview.remoteFolderExists, isFalse);
    expect(preview.spaceId, "space-new");
    expect(preview.remoteDeviceCount, 0);
    expect(preview.merged.wordbookEntries, 0);
    expect(cloud.files, isEmpty);
    expect(cloud.createdDirectories, isEmpty);
  });
}

SyncSnapshot snapshot({
  required String device,
  required List<SyncRecord> records,
}) => SyncSnapshot(spaceId: "space-1", deviceId: device, records: records);

SyncRecord record({
  required String id,
  required String version,
  required String word,
}) => SyncRecord(
  entityType: "wordbook-entry",
  entityId: id,
  versionId: version,
  parentVersionIds: const [],
  modifiedAt: DateTime.utc(2026),
  data: {
    "word": word,
    "tagName": null,
    "createdAt": "2026-01-01T00:00:00.000Z",
  },
  deleted: false,
);

class _MemoryCloudFileStore implements CloudFileStore {
  final Map<String, Uint8List> files = {};
  final Set<String> directories = {};
  final Set<String> createdDirectories = {};

  @override
  Future<void> ensureDirectory(String remotePath) async {
    createdDirectories.add(remotePath);
  }

  @override
  Future<List<CloudFileEntry>> listDirectory(String remotePath) async {
    final normalized = remotePath.replaceAll(RegExp(r"/+$"), "");
    final prefix = normalized.isEmpty ? "" : "$normalized/";
    final entries = <String, CloudFileEntry>{};
    for (final directory in directories) {
      if (!directory.startsWith(prefix) || directory == normalized) continue;
      final remaining = directory.substring(prefix.length);
      final name = remaining.split("/").first;
      final path = prefix + name;
      entries[path] = CloudFileEntry(name: name, path: path, isDirectory: true);
    }
    for (final entry in files.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final remaining = entry.key.substring(prefix.length);
      if (remaining.contains("/")) continue;
      entries[entry.key] = CloudFileEntry(
        name: remaining,
        path: entry.key,
        isDirectory: false,
        sizeBytes: entry.value.length,
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
    if (bytes == null) throw FileSystemException("Not found", remotePath);
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
    createdDirectories.add(remotePath);
    final bytes = await source.readAsBytes();
    files[remotePath] = Uint8List.fromList(bytes);
    onSendProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    files.remove(remotePath);
  }

  @override
  Future<void> close() async {}
}

import "dart:convert";
import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/backup/backup.dart";
import "package:ciyue/services/cloud_sync/coordinator.dart";
import "package:ciyue/services/cloud_sync/dictionary_sync.dart";
import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:ciyue/services/cloud_sync/snapshot_builder.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:path/path.dart" as p;

class CloudSyncDataSummary {
  final int wordbookEntries;
  final int wordbookTags;
  final int flashcards;
  final int reviewLogs;

  const CloudSyncDataSummary({
    required this.wordbookEntries,
    required this.wordbookTags,
    required this.flashcards,
    required this.reviewLogs,
  });
}

class CloudSyncPreview {
  final bool remoteFolderExists;
  final String spaceId;
  final int remoteDeviceCount;
  final CloudSyncDataSummary local;
  final CloudSyncDataSummary remote;
  final CloudSyncDataSummary merged;
  final List<SyncConflict> conflicts;
  final DictionarySyncPreview? dictionaryPreview;

  CloudSyncPreview({
    this.dictionaryPreview,
    required this.remoteFolderExists,
    required this.spaceId,
    required this.remoteDeviceCount,
    required this.local,
    required this.remote,
    required this.merged,
    required List<SyncConflict> conflicts,
  }) : conflicts = List.unmodifiable(conflicts);
}

/// Builds a read-only preview of local and remote sync data before applying it.
class CloudSyncPreviewService {
  final AppDatabase database;
  final CloudSyncSnapshotBuilder snapshotBuilder;
  final CloudSyncEngine mergeEngine;

  const CloudSyncPreviewService({
    required this.database,
    this.snapshotBuilder = const CloudSyncSnapshotBuilder(),
    this.mergeEngine = const CloudSyncEngine(),
  });

  Future<CloudSyncPreview> preview({
    required CloudFileStore fileStore,
    required String remoteRoot,
    required String deviceId,
    required String generatedSpaceId,
    String? expectedSpaceId,
    SyncSnapshot? previousLocalSnapshot,
  }) async {
    final root = normalizeCloudSyncRemoteRoot(remoteRoot);
    final remoteFolder = await _findDirectory(fileStore, root);
    final remoteSnapshots = <SyncSnapshot>[];
    var existingSpaceId = await _readSpaceId(fileStore, remoteFolder);
    if (remoteFolder != null) {
      final syncDirectory = _findChild(remoteFolder.entries, "sync");
      if (syncDirectory != null && syncDirectory.isDirectory) {
        final syncEntries = await fileStore.listDirectory(syncDirectory.path);
        final devicesDirectory = _findChild(syncEntries, "devices");
        if (devicesDirectory != null && devicesDirectory.isDirectory) {
          final deviceEntries = await fileStore.listDirectory(
            devicesDirectory.path,
          );
          final snapshotFiles =
              deviceEntries
                  .where(
                    (entry) =>
                        !entry.isDirectory &&
                        entry.name.endsWith(".json") &&
                        _validDeviceId(
                          entry.name.substring(0, entry.name.length - 5),
                        ),
                  )
                  .toList(growable: false)
                ..sort((a, b) => a.name.compareTo(b.name));
          final temporaryDirectory = await Directory.systemTemp.createTemp(
            "ciyue-sync-preview-",
          );
          try {
            for (var index = 0; index < snapshotFiles.length; index++) {
              final entry = snapshotFiles[index];
              final file = File(p.join(temporaryDirectory.path, "$index.json"));
              await fileStore.downloadFile(entry.path, file);
              final snapshot = SyncSnapshot.decode(await file.readAsString());
              final fileDeviceId = entry.name.substring(
                0,
                entry.name.length - 5,
              );
              if (snapshot.deviceId != fileDeviceId) {
                throw FormatException(
                  "Sync file '${entry.name}' contains a different device ID.",
                );
              }
              remoteSnapshots.add(snapshot);
            }
          } finally {
            await temporaryDirectory.delete(recursive: true);
          }
        }
      }
    }

    existingSpaceId ??= remoteSnapshots.firstOrNull?.spaceId;
    final spaceId = existingSpaceId ?? expectedSpaceId ?? generatedSpaceId;
    if (expectedSpaceId != null && expectedSpaceId != spaceId) {
      throw StateError(
        "This local sync state belongs to '$expectedSpaceId', "
        "but the selected cloud folder belongs to '$spaceId'.",
      );
    }
    if (spaceId.isEmpty) throw ArgumentError.value(spaceId, "spaceId");

    final previous = previousLocalSnapshot;
    if (previous != null && previous.spaceId != spaceId) {
      throw StateError("Local sync history belongs to another cloud folder.");
    }
    final localSnapshot = snapshotBuilder.capture(
      data: await _readLocalData(),
      spaceId: spaceId,
      deviceId: deviceId,
      previous: previous,
    );

    SyncSnapshot? remoteSnapshot;
    for (final snapshot in remoteSnapshots) {
      remoteSnapshot = remoteSnapshot == null
          ? snapshot
          : mergeEngine.merge(remoteSnapshot, snapshot).snapshot;
    }
    final mergeResult = remoteSnapshot == null
        ? SyncMergeResult(snapshot: localSnapshot, conflicts: const [])
        : mergeEngine.merge(localSnapshot, remoteSnapshot);

    return CloudSyncPreview(
      remoteFolderExists: remoteFolder != null,
      spaceId: spaceId,
      remoteDeviceCount: remoteSnapshots.length,
      local: _summarize(localSnapshot.latestRecords),
      remote: _summarize(remoteSnapshot?.latestRecords ?? const []),
      merged: _summarize(mergeResult.snapshot.latestRecords),
      conflicts: mergeResult.conflicts,
    );
  }

  Future<BackupData> _readLocalData() async => BackupData(
    version: BackupData.currentVersion,
    wordbookWords: await database.wordbookDao.getAllWords(),
    wordbookTags: await database.wordbookTagsDao.getAllTags(),
    flashcards: await database.flashcardDao.getAllCards(),
    flashcardReviewLogs: await database.flashcardDao.getReviewLogs(),
  );
}

CloudSyncDataSummary _summarize(Iterable<SyncRecord> records) {
  final liveByType = <String, Set<String>>{};
  for (final record in records) {
    if (record.deleted) continue;
    liveByType.putIfAbsent(record.entityType, () => {}).add(record.entityId);
  }
  return CloudSyncDataSummary(
    wordbookEntries: liveByType["wordbook-entry"]?.length ?? 0,
    wordbookTags: liveByType["wordbook-tag"]?.length ?? 0,
    flashcards: liveByType["flashcard"]?.length ?? 0,
    reviewLogs: liveByType["flashcard-review-log"]?.length ?? 0,
  );
}

Future<_RemoteDirectory?> _findDirectory(
  CloudFileStore fileStore,
  String remotePath,
) async {
  var entries = await fileStore.listDirectory("");
  var path = "";
  for (final segment in remotePath.split("/")) {
    final directory = _findChild(entries, segment);
    if (directory == null || !directory.isDirectory) return null;
    path = path.isEmpty ? directory.name : p.posix.join(path, directory.name);
    entries = await fileStore.listDirectory(path);
  }
  return _RemoteDirectory(path: path, entries: entries);
}

Future<String?> _readSpaceId(
  CloudFileStore fileStore,
  _RemoteDirectory? remoteFolder,
) async {
  if (remoteFolder == null) return null;
  final syncDirectory = _findChild(remoteFolder.entries, "sync");
  if (syncDirectory == null || !syncDirectory.isDirectory) return null;
  final entries = await fileStore.listDirectory(syncDirectory.path);
  final manifest = _findChild(entries, "space.json");
  if (manifest == null || manifest.isDirectory) return null;

  final directory = await Directory.systemTemp.createTemp(
    "ciyue-space-preview-",
  );
  try {
    final file = File(p.join(directory.path, "space.json"));
    await fileStore.downloadFile(manifest.path, file);
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map ||
        decoded["app"] != "ciyue" ||
        decoded["formatVersion"] != 1 ||
        decoded["spaceId"] is! String ||
        (decoded["spaceId"] as String).isEmpty) {
      throw const FormatException("Invalid Ciyue cloud-space manifest.");
    }
    return decoded["spaceId"] as String;
  } finally {
    await directory.delete(recursive: true);
  }
}

CloudFileEntry? _findChild(List<CloudFileEntry> entries, String name) {
  for (final entry in entries) {
    if (entry.name == name) return entry;
  }
  return null;
}

bool _validDeviceId(String deviceId) =>
    deviceId.isNotEmpty && RegExp(r"^[A-Za-z0-9_-]+$").hasMatch(deviceId);

class _RemoteDirectory {
  final String path;
  final List<CloudFileEntry> entries;

  const _RemoteDirectory({required this.path, required this.entries});
}

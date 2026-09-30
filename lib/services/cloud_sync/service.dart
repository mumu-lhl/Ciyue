import "dart:convert";
import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/backup/backup.dart";
import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:ciyue/services/cloud_sync/apply_service.dart";
import "package:ciyue/services/cloud_sync/coordinator.dart";
import "package:ciyue/services/cloud_sync/snapshot_builder.dart";
import "package:path/path.dart" as p;

abstract interface class SyncSnapshotStateStore {
  Future<SyncSnapshot?> read();

  Future<void> write(SyncSnapshot snapshot);
}

/// Persists the last successfully applied snapshot needed to detect local
/// edits and deletions on the next sync.
class FileSyncSnapshotStateStore implements SyncSnapshotStateStore {
  final File file;

  const FileSyncSnapshotStateStore(this.file);

  @override
  Future<SyncSnapshot?> read() async {
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return SyncSnapshot.decode(content);
  }

  @override
  Future<void> write(SyncSnapshot snapshot) async {
    await file.parent.create(recursive: true);
    final temporary = File("${file.path}.tmp");
    if (await temporary.exists()) {
      await temporary.delete();
    }
    try {
      await temporary.writeAsString(snapshot.encode(), flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await temporary.rename(file.path);
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }
}

/// Connects local Drift data, the merge coordinator, and the cloud file store.
class CloudSyncService {
  final AppDatabase database;
  final String deviceId;
  final String spaceId;
  final String remoteRoot;
  final CloudFileStore fileStore;
  final SyncSnapshotStateStore stateStore;
  final CloudSyncSnapshotBuilder snapshotBuilder;
  final CloudSyncCoordinator coordinator;
  final CloudSyncApplyService applyService;

  CloudSyncService({
    required this.database,
    required this.deviceId,
    required this.spaceId,
    required this.remoteRoot,
    required this.fileStore,
    required this.stateStore,
    this.snapshotBuilder = const CloudSyncSnapshotBuilder(),
    CloudSyncCoordinator? coordinator,
    CloudSyncApplyService? applyService,
  }) : coordinator = coordinator ?? CloudSyncCoordinator(),
       applyService = applyService ?? CloudSyncApplyService(database: database);

  Future<CloudSyncOutcome> sync() async {
    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final previous = await stateStore.read();
      if (previous != null && previous.spaceId != spaceId) {
        throw StateError(
          "Local sync state belongs to '${previous.spaceId}', not '$spaceId'.",
        );
      }

      final localSnapshot = snapshotBuilder.capture(
        data: await _readLocalData(),
        spaceId: spaceId,
        deviceId: deviceId,
        previous: previous,
      );
      final outcome = await coordinator.sync(
        fileStore: fileStore,
        remoteRoot: remoteRoot,
        localSnapshot: localSnapshot,
      );
      if (outcome.conflicts.isNotEmpty) return outcome;

      try {
        await applyService.apply(
          outcome.snapshot,
          expectedLocalSnapshot: localSnapshot,
          previousLocalSnapshot: previous,
        );
      } on CloudSyncLocalChangedException {
        if (attempt + 1 == maxAttempts) rethrow;
        continue;
      }

      await stateStore.write(outcome.snapshot);
      return outcome;
    }
    throw StateError("Cloud sync could not stabilize local data.");
  }

  Future<BackupData> _readLocalData() async => BackupData(
    version: BackupData.currentVersion,
    wordbookWords: await database.wordbookDao.getAllWords(),
    wordbookTags: await database.wordbookTagsDao.getAllTags(),
    flashcards: await database.flashcardDao.getAllCards(),
    flashcardReviewLogs: await database.flashcardDao.getReviewLogs(),
  );
}

/// Chooses the app-support location for a particular cloud sync space.
FileSyncSnapshotStateStore fileSyncSnapshotStateStore(
  Directory appSupportDirectory,
  String spaceId,
) {
  final safeSpaceId = base64Url
      .encode(utf8.encode(spaceId))
      .replaceAll("=", "");
  return FileSyncSnapshotStateStore(
    File(p.join(appSupportDirectory.path, "cloud_sync", "$safeSpaceId.json")),
  );
}

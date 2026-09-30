import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/backup/backup.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:ciyue/services/cloud_sync/backup_codec.dart";
import "package:ciyue/services/cloud_sync/snapshot_builder.dart";

class CloudSyncLocalChangedException implements Exception {
  const CloudSyncLocalChangedException();

  @override
  String toString() => "Local Ciyue data changed while cloud sync was running.";
}

/// Replaces the synced portion of local Drift data with a conflict-free merged
/// snapshot in one transaction. Search history and unrelated settings remain
/// local to each device.
class CloudSyncApplyService {
  final AppDatabase database;
  final CloudSyncBackupCodec codec;
  final CloudSyncSnapshotBuilder snapshotBuilder;

  const CloudSyncApplyService({
    required this.database,
    this.codec = const CloudSyncBackupCodec(),
    this.snapshotBuilder = const CloudSyncSnapshotBuilder(),
  });

  Future<void> apply(
    SyncSnapshot snapshot, {
    SyncSnapshot? expectedLocalSnapshot,
    SyncSnapshot? previousLocalSnapshot,
  }) async {
    await database.transaction(() async {
      if (expectedLocalSnapshot != null) {
        final currentLocalSnapshot = snapshotBuilder.capture(
          data: await _readLocalData(),
          spaceId: expectedLocalSnapshot.spaceId,
          deviceId: expectedLocalSnapshot.deviceId,
          previous: previousLocalSnapshot,
        );
        if (currentLocalSnapshot.encode() != expectedLocalSnapshot.encode()) {
          throw const CloudSyncLocalChangedException();
        }
      }

      final currentTags = await database.wordbookTagsDao.getAllTags();
      final backup = codec.decode(snapshot, localTags: currentTags);

      await database.delete(database.wordbook).go();
      await database.delete(database.wordbookTags).go();
      await database.delete(database.flashcards).go();
      await database.delete(database.flashcardReviewLogs).go();

      await database.wordbookTagsDao.addAllTags(backup.wordbookTags);
      await database.wordbookDao.addAllWords(backup.wordbookWords);
      await database.flashcardDao.addAllCards(backup.flashcards);
      await database.flashcardDao.addAllReviewLogs(backup.flashcardReviewLogs);
    });
  }

  Future<BackupData> _readLocalData() async => BackupData(
    version: BackupData.currentVersion,
    wordbookWords: await database.wordbookDao.getAllWords(),
    wordbookTags: await database.wordbookTagsDao.getAllTags(),
    flashcards: await database.flashcardDao.getAllCards(),
    flashcardReviewLogs: await database.flashcardDao.getReviewLogs(),
  );
}

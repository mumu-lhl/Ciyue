import "dart:io";
import "dart:typed_data";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:ciyue/services/cloud_sync/service.dart";
import "package:drift/native.dart";
import "package:dio/dio.dart" show ProgressCallback;
import "package:drift/drift.dart" show Value, driftRuntimeOptions;
import "package:flutter_test/flutter_test.dart";

void main() {
  late AppDatabase firstDatabase;
  late AppDatabase secondDatabase;
  late _MemoryCloudFileStore cloud;
  late _MemorySyncStateStore firstState;
  late _MemorySyncStateStore secondState;
  late bool previousMultipleDatabaseWarning;

  setUpAll(() {
    previousMultipleDatabaseWarning =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases =
        previousMultipleDatabaseWarning;
  });

  setUp(() {
    firstDatabase = AppDatabase(NativeDatabase.memory());
    secondDatabase = AppDatabase(NativeDatabase.memory());
    cloud = _MemoryCloudFileStore();
    firstState = _MemorySyncStateStore();
    secondState = _MemorySyncStateStore();
  });

  tearDown(() async {
    await firstDatabase.close();
    await secondDatabase.close();
  });

  CloudSyncService service(
    AppDatabase database,
    String device,
    SyncSnapshotStateStore state,
  ) => CloudSyncService(
    database: database,
    deviceId: device,
    spaceId: "space-1",
    remoteRoot: "Ciyue",
    fileStore: cloud,
    stateStore: state,
  );

  test("a second device restores wordbook and FSRS state from cloud", () async {
    final tagId = await firstDatabase
        .into(firstDatabase.wordbookTags)
        .insert(const WordbookTagsCompanion(tag: Value("Fruit")));
    await firstDatabase.wordbookDao.addWord("apple", tag: tagId);
    await firstDatabase.flashcardDao.putCard(
      word: "apple",
      state: 2,
      due: DateTime.utc(2026, 4, 5),
      lastReview: DateTime.utc(2026, 4, 1),
      introducedAt: DateTime.utc(2026, 3, 20),
    );
    await firstDatabase.flashcardDao.addReviewLog(
      word: "apple",
      rating: 2,
      reviewedAt: DateTime.utc(2026, 4, 1),
      durationMs: 600,
    );

    final firstResult = await service(
      firstDatabase,
      "device-a",
      firstState,
    ).sync();
    expect(firstResult.conflicts, isEmpty);

    final secondResult = await service(
      secondDatabase,
      "device-b",
      secondState,
    ).sync();

    expect(secondResult.conflicts, isEmpty);
    expect(
      (await secondDatabase.wordbookDao.getAllWords()).single.word,
      "apple",
    );
    expect(
      (await secondDatabase.wordbookTagsDao.getAllTags()).single.tag,
      "Fruit",
    );
    expect((await secondDatabase.flashcardDao.getAllCards()).single.state, 2);
    expect(
      (await secondDatabase.flashcardDao.getReviewLogs()).single.rating,
      2,
    );
    expect(secondState.snapshot?.records, isNotEmpty);
  });

  test("preserves local edits made while a snapshot uploads", () async {
    await firstDatabase.wordbookDao.addWord("apple");
    cloud.onBeforeUpload = () async {
      cloud.onBeforeUpload = null;
      await firstDatabase.wordbookDao.addWord("banana");
    };

    final result = await service(firstDatabase, "device-a", firstState).sync();

    expect(result.conflicts, isEmpty);
    expect(
      (await firstDatabase.wordbookDao.getAllWords())
          .map((word) => word.word)
          .toSet(),
      {"apple", "banana"},
    );
    expect(firstState.snapshot?.latestRecords, hasLength(2));
  });

  test(
    "wordbook deletions propagate as tombstones to another device",
    () async {
      final tagId = await firstDatabase
          .into(firstDatabase.wordbookTags)
          .insert(const WordbookTagsCompanion(tag: Value("Fruit")));
      await firstDatabase.wordbookDao.addWord("apple", tag: tagId);
      await service(firstDatabase, "device-a", firstState).sync();
      await service(secondDatabase, "device-b", secondState).sync();
      expect(await secondDatabase.wordbookDao.countTotalWords(), 1);

      await firstDatabase.wordbookDao.removeWord("apple", tag: tagId);
      await service(firstDatabase, "device-a", firstState).sync();
      await service(secondDatabase, "device-b", secondState).sync();

      expect(await firstDatabase.wordbookDao.countTotalWords(), 0);
      expect(await secondDatabase.wordbookDao.countTotalWords(), 0);
    },
  );

  test("concurrent edits between two devices auto-resolve with Last-Write-Wins and converge cleanly", () async {
    await firstDatabase.wordbookDao.addWord("apple");
    await service(firstDatabase, "device-a", firstState).sync();
    await service(secondDatabase, "device-b", secondState).sync();

    // Device A reviews apple
    await firstDatabase.flashcardDao.putCard(
      word: "apple",
      state: 2,
      due: DateTime.utc(2026, 4, 2),
      lastReview: DateTime.utc(2026, 4, 1, 10),
      introducedAt: DateTime.utc(2026, 3, 20),
    );
    await service(firstDatabase, "device-a", firstState).sync();

    // Device B concurrently reviews apple later
    await secondDatabase.flashcardDao.putCard(
      word: "apple",
      state: 3,
      due: DateTime.utc(2026, 4, 10),
      lastReview: DateTime.utc(2026, 4, 1, 12),
      introducedAt: DateTime.utc(2026, 3, 20),
    );
    final outcomeB = await service(
      secondDatabase,
      "device-b",
      secondState,
    ).sync();

    // Device B auto-resolves the conflict and saves state
    expect(outcomeB.conflicts, isEmpty);
    expect((await secondDatabase.flashcardDao.getAllCards()).single.state, 3);

    // Device A syncs and converges to Device B's newer review
    final outcomeA = await service(
      firstDatabase,
      "device-a",
      firstState,
    ).sync();
    expect(outcomeA.conflicts, isEmpty);
    expect((await firstDatabase.flashcardDao.getAllCards()).single.state, 3);
  });
}

class _MemorySyncStateStore implements SyncSnapshotStateStore {
  SyncSnapshot? snapshot;

  @override
  Future<SyncSnapshot?> read() async => snapshot;

  @override
  Future<void> write(SyncSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}

class _MemoryCloudFileStore implements CloudFileStore {
  final Map<String, Uint8List> files = {};
  final Set<String> directories = {};
  Future<void> Function()? onBeforeUpload;

  @override
  Future<void> ensureDirectory(String remotePath) async {
    directories.add(remotePath);
  }

  @override
  Future<List<CloudFileEntry>> listDirectory(String remotePath) async {
    final prefix = remotePath.endsWith("/") ? remotePath : "$remotePath/";
    return [
      for (final entry in files.entries)
        if (entry.key.startsWith(prefix) &&
            !entry.key.substring(prefix.length).contains("/"))
          CloudFileEntry(
            name: entry.key.substring(prefix.length),
            path: entry.key,
            isDirectory: false,
            sizeBytes: entry.value.length,
          ),
    ];
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
    await onBeforeUpload?.call();
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

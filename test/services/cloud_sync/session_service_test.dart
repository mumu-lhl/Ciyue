import "dart:io";
import "dart:typed_data";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/cloud_sync/configuration.dart";
import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:ciyue/services/cloud_sync/session_service.dart";
import "package:dio/dio.dart" show ProgressCallback;
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SharedPreferencesWithCache preferences;
  late _MemoryCloudSecretStorage secrets;
  late _MemoryCloudFileStore cloud;
  late Directory supportDirectory;
  late CloudSyncSessionService session;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: CloudSyncConfigurationStore.preferenceKeys,
      ),
    );
    secrets = _MemoryCloudSecretStorage();
    cloud = _MemoryCloudFileStore();
    supportDirectory = await Directory.systemTemp.createTemp(
      "ciyue-session-test-",
    );
    session = CloudSyncSessionService(
      database: database,
      configurationStore: CloudSyncConfigurationStore(
        preferences: preferences,
        secretStorage: secrets,
      ),
      fileStoreFactory: ({required settings}) => cloud,
      appSupportDirectoryProvider: () async => supportDirectory,
    );
  });

  tearDown(() async {
    await database.close();
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test(
    "requires a preview before connecting and then syncs the confirmed folder",
    () async {
      await database.wordbookDao.addWord("apple");

      final settings = _webDavSettings();
      final preview = await session.preview(settings: settings);

      expect(preview.remoteFolderExists, isFalse);
      expect(preview.local.wordbookEntries, 1);
      expect(cloud.files, isEmpty);
      expect(cloud.directories, isEmpty);
      expect((await session.loadConfiguration()).isConfigured, isFalse);

      final result = await session.connectAndSync(
        settings: settings,
        previewedSpaceId: preview.spaceId,
      );

      expect(result.conflicts, isEmpty);
      expect(cloud.files.keys, contains("Ciyue/sync/space.json"));
      expect(
        cloud.files.keys,
        contains("Ciyue/sync/devices/${result.snapshot.deviceId}.json"),
      );
      expect((await session.loadConfiguration()).spaceId, preview.spaceId);
      expect(secrets.values, isEmpty);
    },
  );

  test("uploads a checked dictionary only after sync confirmation", () async {
    final basePath = "${supportDirectory.path}/source/lexicon";
    final mdx = File("$basePath.mdx");
    await mdx.parent.create(recursive: true);
    await mdx.writeAsString("mdx dictionary");
    await database.dictionaryListDao.add(basePath, "Lexicon");

    final settings = _webDavSettings();
    final preview = await session.preview(settings: settings);
    expect(preview.dictionaryPreview!.items, hasLength(1));
    final dictionary = preview.dictionaryPreview!.items.single;
    expect(cloud.files, isEmpty);

    await session.connectAndSync(
      settings: settings,
      previewedSpaceId: preview.spaceId,
      selectedDictionaryPackageIds: {dictionary.packageId},
      dictionaryPreview: preview.dictionaryPreview,
    );

    expect(
      cloud.files.keys,
      contains(
        "Ciyue/dictionaries/packages/${dictionary.packageId}/lexicon.mdx",
      ),
    );
    expect(
      cloud.files.keys,
      contains(
        "Ciyue/dictionaries/packages/${dictionary.packageId}/manifest.json",
      ),
    );
  });

  test(
    "syncs the saved profile without re-uploading an unchanged snapshot",
    () async {
      await database.wordbookDao.addWord("apple");
      final settings = _webDavSettings();
      final preview = await session.preview(settings: settings);
      await session.connectAndSync(
        settings: settings,
        previewedSpaceId: preview.spaceId,
      );

      final result = await session.syncConfigured();

      expect(result.conflicts, isEmpty);
      expect(result.uploaded, isFalse);
    },
  );
}

CloudSyncConnectionSettings _webDavSettings() =>
    const CloudSyncConnectionSettings(
      endpoint: "https://dav.example.test/",
      remoteRoot: "Ciyue",
      username: "",
    );

class _MemoryCloudSecretStorage implements CloudSecretStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _MemoryCloudFileStore implements CloudFileStore {
  final Map<String, Uint8List> files = {};
  final Set<String> directories = {};

  @override
  Future<void> ensureDirectory(String remotePath) async {
    var path = "";
    for (final segment in remotePath.split("/")) {
      if (segment.isEmpty) continue;
      path = path.isEmpty ? segment : "$path/$segment";
      directories.add(path);
    }
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
      final path = "$prefix$name";
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

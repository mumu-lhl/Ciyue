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
      fileStoreFactory: ({required baseUri, username, password}) => cloud,
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

      final preview = await session.preview(
        endpoint: "https://dav.example.test/",
        remoteRoot: "Ciyue",
        username: "",
        password: null,
      );

      expect(preview.remoteFolderExists, isFalse);
      expect(preview.local.wordbookEntries, 1);
      expect(cloud.files, isEmpty);
      expect(cloud.directories, isEmpty);
      expect((await session.loadConfiguration()).isConfigured, isFalse);

      final result = await session.connectAndSync(
        endpoint: "https://dav.example.test/",
        remoteRoot: "Ciyue",
        username: "",
        password: null,
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

    final preview = await session.preview(
      endpoint: "https://dav.example.test/",
      remoteRoot: "Ciyue",
      username: "",
      password: null,
    );
    expect(preview.dictionaryPreview!.items, hasLength(1));
    final dictionary = preview.dictionaryPreview!.items.single;
    expect(cloud.files, isEmpty);

    await session.connectAndSync(
      endpoint: "https://dav.example.test/",
      remoteRoot: "Ciyue",
      username: "",
      password: null,
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

  test("uses the selected Google Drive folder and stores the provider profile only after confirmation", () async {
    final selectedFolder = _MemoryCloudFileStore();
    CloudSyncProvider? factoryProvider;
    String? selectedParentId;
    session = CloudSyncSessionService(
      database: database,
      configurationStore: CloudSyncConfigurationStore(
        preferences: preferences,
        secretStorage: secrets,
      ),
      providerFileStoreFactory:
          ({
            required provider,
            required accessTokenProvider,
            googleDriveParentFolderId,
          }) {
            factoryProvider = provider;
            selectedParentId = googleDriveParentFolderId;
            return selectedFolder;
          },
      appSupportDirectoryProvider: () async => supportDirectory,
    );
    await secrets.write(
      "ciyue.cloud_sync.oauth.googleDrive",
      '{"nativeGoogleSignIn":true}',
    );

    final preview = await session.preview(
      provider: CloudSyncProvider.googleDrive,
      googleDriveParentFolderId: "drive-parent",
      endpoint: "",
      remoteRoot: "Ciyue",
      username: "",
      password: null,
    );
    expect(factoryProvider, CloudSyncProvider.googleDrive);
    expect(selectedParentId, "drive-parent");
    expect(preview.remoteFolderExists, isFalse);
    expect(selectedFolder.files, isEmpty);

    await session.connectAndSync(
      provider: CloudSyncProvider.googleDrive,
      googleDriveParentFolderId: "drive-parent",
      googleDriveParentFolderName: "Study",
      endpoint: "",
      remoteRoot: "Ciyue",
      username: "",
      password: null,
      previewedSpaceId: preview.spaceId,
    );

    final configuration = await session.loadConfiguration();
    expect(configuration.provider, CloudSyncProvider.googleDrive);
    expect(configuration.googleDriveParentFolderId, "drive-parent");
    expect(configuration.googleDriveParentFolderName, "Study");
    expect(configuration.isConfigured, isTrue);
    expect(selectedFolder.files.keys, contains("Ciyue/sync/space.json"));
  });

  test(
    "disconnecting one OAuth provider preserves other credentials and profiles",
    () async {
      await session.configurationStore.saveConnection(
        endpoint: "https://dav.example.test/",
        remoteRoot: "Ciyue",
        username: "",
        password: "",
      );
      await secrets.write("ciyue.cloud_sync.oauth.googleDrive", "google");
      await secrets.write("ciyue.cloud_sync.oauth.oneDrive", "microsoft");

      await session.disconnect(provider: CloudSyncProvider.googleDrive);

      expect(secrets.values, {"ciyue.cloud_sync.oauth.oneDrive": "microsoft"});
      var configuration = await session.loadConfiguration();
      expect(configuration.provider, CloudSyncProvider.webDav);
      expect(configuration.isConfigured, isTrue);

      await secrets.write("ciyue.cloud_sync.oauth.googleDrive", "google-again");
      await session.configurationStore.saveOAuthConnection(
        provider: CloudSyncProvider.googleDrive,
        remoteRoot: "Ciyue",
        googleDriveParentFolderId: "parent",
        googleDriveParentFolderName: "Study",
      );
      await session.disconnect(provider: CloudSyncProvider.googleDrive);

      expect(secrets.values, {"ciyue.cloud_sync.oauth.oneDrive": "microsoft"});
      configuration = await session.loadConfiguration();
      expect(configuration.provider, CloudSyncProvider.webDav);
      expect(configuration.isConfigured, isFalse);
    },
  );

  test(
    "syncs the saved profile without re-uploading an unchanged snapshot",
    () async {
      await database.wordbookDao.addWord("apple");
      final preview = await session.preview(
        endpoint: "https://dav.example.test/",
        remoteRoot: "Ciyue",
        username: "",
        password: null,
      );
      await session.connectAndSync(
        endpoint: "https://dav.example.test/",
        remoteRoot: "Ciyue",
        username: "",
        password: null,
        previewedSpaceId: preview.spaceId,
      );

      final result = await session.syncConfigured();

      expect(result.conflicts, isEmpty);
      expect(result.uploaded, isFalse);
    },
  );
}

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

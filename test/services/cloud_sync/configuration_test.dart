import "package:ciyue/services/cloud_sync/configuration.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesWithCache preferences;
  late _MemoryCloudSecretStorage secrets;
  late CloudSyncConfigurationStore store;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: CloudSyncConfigurationStore.preferenceKeys,
      ),
    );
    secrets = _MemoryCloudSecretStorage();
    store = CloudSyncConfigurationStore(
      preferences: preferences,
      secretStorage: secrets,
    );
  });

  test(
    "stores the WebDAV password in secure storage and reuses device ID",
    () async {
      final initial = await store.load();
      await store.saveConnection(
        endpoint: "https://dav.example.test/remote.php/dav/files/alice/",
        remoteRoot: "Ciyue",
        username: "alice",
        password: "secret",
      );

      final loaded = await store.load();

      expect(
        loaded.endpoint,
        "https://dav.example.test/remote.php/dav/files/alice/",
      );
      expect(loaded.remoteRoot, "Ciyue");
      expect(loaded.username, "alice");
      expect(loaded.password, "secret");
      expect(loaded.deviceId, initial.deviceId);
      expect(loaded.spaceId, isNull);
      final storedKeys = await SharedPreferencesAsync().getKeys();
      expect(storedKeys, isNot(contains("cloudSyncPassword")));
      expect(storedKeys, isNot(contains("ciyue.cloud_sync.webdav.password")));
      expect(secrets.values.values, contains("secret"));
    },
  );

  test(
    "changing the cloud folder clears its previous space identity",
    () async {
      await store.saveConnection(
        endpoint: "https://dav.example.test/",
        remoteRoot: "Ciyue",
        username: "",
        password: "",
      );
      await store.saveSpaceId("space-one");

      final changed = await store.saveConnection(
        endpoint: "https://dav.example.test/",
        remoteRoot: "Ciyue/new-folder",
        username: "",
        password: "",
      );

      expect(changed.spaceId, isNull);
      expect(await store.loadSpaceId(), isNull);
    },
  );

  test("stores OAuth provider and folder selection without persisting tokens in preferences", () async {
    final initial = await store.load();
    await secrets.write(
      "ciyue.cloud_sync.oauth.googleDrive",
      '{"accessToken":"token"}',
    );

    await store.saveOAuthConnection(
      provider: CloudSyncProvider.googleDrive,
      remoteRoot: "Ciyue",
      googleDriveParentFolderId: "drive-parent",
      googleDriveParentFolderName: "Study",
    );
    final loaded = await store.load();

    expect(loaded.provider, CloudSyncProvider.googleDrive);
    expect(loaded.isConfigured, isTrue);
    expect(loaded.googleDriveParentFolderId, "drive-parent");
    expect(loaded.googleDriveParentFolderName, "Study");
    expect(loaded.deviceId, initial.deviceId);
    expect(
      await SharedPreferencesAsync().getKeys(),
      isNot(contains("ciyue.cloud_sync.oauth.googleDrive")),
    );
  });

  test(
    "disconnect clears the secret and remote profile but keeps device ID",
    () async {
      final before = await store.load();
      await store.saveConnection(
        endpoint: "https://dav.example.test/",
        remoteRoot: "Ciyue",
        username: "alice",
        password: "secret",
      );

      await store.disconnect();
      final after = await store.load();

      expect(after.endpoint, isEmpty);
      expect(after.remoteRoot, "Ciyue");
      expect(after.username, isEmpty);
      expect(after.password, isNull);
      expect(after.deviceId, before.deviceId);
      expect(secrets.values, isEmpty);
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

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
        settings: const CloudSyncConnectionSettings(
          endpoint: "https://dav.example.test/remote.php/dav/files/alice/",
          remoteRoot: "Ciyue",
          username: "alice",
          password: "secret",
        ),
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
        settings: const CloudSyncConnectionSettings(
          endpoint: "https://dav.example.test/",
          remoteRoot: "Ciyue",
          username: "",
        ),
      );
      await store.saveSpaceId("space-one");

      final changed = await store.saveConnection(
        settings: const CloudSyncConnectionSettings(
          endpoint: "https://dav.example.test/",
          remoteRoot: "Ciyue/new-folder",
          username: "",
        ),
      );

      expect(changed.spaceId, isNull);
      expect(await store.loadSpaceId(), isNull);
    },
  );

  test("stores SFTP and S3 credentials only in secure storage", () async {
    await store.saveConnection(
      settings: const CloudSyncConnectionSettings(
        provider: CloudSyncProvider.sftp,
        endpoint: "sftp://nas.example.test:22/backups",
        remoteRoot: "Ciyue",
        username: "alice",
        password: "sftp-password",
        sftpHostKeyFingerprint: "SHA256:known-host",
        sftpPrivateKey: "private-key-pem",
        sftpKeyPassphrase: "key-passphrase",
      ),
    );
    var loaded = await store.load();
    expect(loaded.provider, CloudSyncProvider.sftp);
    expect(loaded.isConfigured, isTrue);
    expect(loaded.password, "sftp-password");
    expect(loaded.sftpPrivateKey, "private-key-pem");
    expect(loaded.sftpKeyPassphrase, "key-passphrase");
    expect(loaded.sftpHostKeyFingerprint, "SHA256:known-host");

    await store.saveSpaceId("space-sftp");
    await store.saveConnection(
      settings: const CloudSyncConnectionSettings(
        provider: CloudSyncProvider.s3,
        endpoint: "https://account.r2.example.test",
        remoteRoot: "Ciyue",
        username: "",
        s3Bucket: "ciyue-backups",
        s3Region: "auto",
        s3AccessKeyId: "access-id",
        s3SecretAccessKey: "s3-secret",
        s3UsePathStyle: false,
      ),
    );
    loaded = await store.load();
    expect(loaded.provider, CloudSyncProvider.s3);
    expect(loaded.isConfigured, isTrue);
    expect(loaded.s3Bucket, "ciyue-backups");
    expect(loaded.s3AccessKeyId, "access-id");
    expect(loaded.s3SecretAccessKey, "s3-secret");
    expect(loaded.s3UsePathStyle, isFalse);
    expect(loaded.spaceId, isNull);
    expect(secrets.values.values, contains("s3-secret"));
    expect(secrets.values.values, isNot(contains("sftp-password")));
    final storedPreferences = await SharedPreferencesAsync().getKeys();
    expect(storedPreferences, isNot(contains("s3-secret")));
    expect(storedPreferences, isNot(contains("private-key-pem")));
  });

  test(
    "disconnect clears the secret and remote profile but keeps device ID",
    () async {
      final before = await store.load();
      await store.saveConnection(
        settings: const CloudSyncConnectionSettings(
          endpoint: "https://dav.example.test/",
          remoteRoot: "Ciyue",
          username: "alice",
          password: "secret",
        ),
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

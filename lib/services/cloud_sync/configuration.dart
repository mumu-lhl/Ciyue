import "dart:math";

import "package:shared_preferences/shared_preferences.dart";
import "package:simple_secure_storage/simple_secure_storage.dart";

enum CloudSyncProvider { webDav, sftp, s3 }

class CloudSyncConnectionSettings {
  final CloudSyncProvider provider;
  final String endpoint;
  final String remoteRoot;
  final String username;
  final String? password;
  final String? sftpHostKeyFingerprint;
  final String? sftpPrivateKey;
  final String? sftpKeyPassphrase;
  final String? s3Bucket;
  final String? s3Region;
  final String? s3AccessKeyId;
  final String? s3SecretAccessKey;
  final bool s3UsePathStyle;

  const CloudSyncConnectionSettings({
    this.provider = CloudSyncProvider.webDav,
    required this.endpoint,
    required this.remoteRoot,
    required this.username,
    this.password,
    this.sftpHostKeyFingerprint,
    this.sftpPrivateKey,
    this.sftpKeyPassphrase,
    this.s3Bucket,
    this.s3Region,
    this.s3AccessKeyId,
    this.s3SecretAccessKey,
    this.s3UsePathStyle = true,
  });

  CloudSyncConnectionSettings copyWith({String? remoteRoot}) =>
      CloudSyncConnectionSettings(
        provider: provider,
        endpoint: endpoint,
        remoteRoot: remoteRoot ?? this.remoteRoot,
        username: username,
        password: password,
        sftpHostKeyFingerprint: sftpHostKeyFingerprint,
        sftpPrivateKey: sftpPrivateKey,
        sftpKeyPassphrase: sftpKeyPassphrase,
        s3Bucket: s3Bucket,
        s3Region: s3Region,
        s3AccessKeyId: s3AccessKeyId,
        s3SecretAccessKey: s3SecretAccessKey,
        s3UsePathStyle: s3UsePathStyle,
      );
}

abstract interface class CloudSecretStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SimpleSecureCloudSecretStorage implements CloudSecretStorage {
  const SimpleSecureCloudSecretStorage();

  @override
  Future<String?> read(String key) => SimpleSecureStorage.read(key);

  @override
  Future<void> write(String key, String value) =>
      SimpleSecureStorage.write(key, value);

  @override
  Future<void> delete(String key) => SimpleSecureStorage.delete(key);
}

class CloudSyncConfiguration {
  final CloudSyncProvider provider;
  final String endpoint;
  final String remoteRoot;
  final String username;
  final String? password;
  final String? sftpHostKeyFingerprint;
  final String? sftpPrivateKey;
  final String? sftpKeyPassphrase;
  final String? s3Bucket;
  final String? s3Region;
  final String? s3AccessKeyId;
  final String? s3SecretAccessKey;
  final bool s3UsePathStyle;
  final String deviceId;
  final String? spaceId;

  const CloudSyncConfiguration({
    this.provider = CloudSyncProvider.webDav,
    required this.endpoint,
    required this.remoteRoot,
    required this.username,
    required this.password,
    this.sftpHostKeyFingerprint,
    this.sftpPrivateKey,
    this.sftpKeyPassphrase,
    this.s3Bucket,
    this.s3Region,
    this.s3AccessKeyId,
    this.s3SecretAccessKey,
    this.s3UsePathStyle = true,
    required this.deviceId,
    required this.spaceId,
  });

  bool get isConfigured => switch (provider) {
    CloudSyncProvider.webDav => endpoint.isNotEmpty,
    CloudSyncProvider.sftp =>
      endpoint.isNotEmpty &&
          username.isNotEmpty &&
          (password?.isNotEmpty == true ||
              sftpPrivateKey?.isNotEmpty == true) &&
          sftpHostKeyFingerprint?.isNotEmpty == true,
    CloudSyncProvider.s3 =>
      endpoint.isNotEmpty &&
          s3Bucket?.isNotEmpty == true &&
          s3Region?.isNotEmpty == true &&
          s3AccessKeyId?.isNotEmpty == true &&
          s3SecretAccessKey?.isNotEmpty == true,
  };
}

/// Persists non-secret connection settings in preferences and credentials in
/// the operating system's secure storage.
class CloudSyncConfigurationStore {
  static const providerKey = "cloudSyncProvider";
  static const endpointKey = "cloudSyncEndpoint";
  static const remoteRootKey = "cloudSyncRemoteRoot";
  static const usernameKey = "cloudSyncUsername";
  static const sftpHostKeyFingerprintKey = "cloudSyncSftpHostKeyFingerprint";
  static const s3BucketKey = "cloudSyncS3Bucket";
  static const s3RegionKey = "cloudSyncS3Region";
  static const s3AccessKeyIdKey = "cloudSyncS3AccessKeyId";
  static const s3UsePathStyleKey = "cloudSyncS3UsePathStyle";
  static const deviceIdKey = "cloudSyncDeviceId";
  static const spaceIdKey = "cloudSyncSpaceId";
  static const _webDavPasswordKey = "ciyue.cloud_sync.webdav.password";
  static const _sftpPasswordKey = "ciyue.cloud_sync.sftp.password";
  static const _sftpPrivateKeyKey = "ciyue.cloud_sync.sftp.privateKey";
  static const _sftpKeyPassphraseKey = "ciyue.cloud_sync.sftp.keyPassphrase";
  static const _s3SecretAccessKeyKey = "ciyue.cloud_sync.s3.secretAccessKey";

  static const preferenceKeys = {
    providerKey,
    endpointKey,
    remoteRootKey,
    usernameKey,
    sftpHostKeyFingerprintKey,
    s3BucketKey,
    s3RegionKey,
    s3AccessKeyIdKey,
    s3UsePathStyleKey,
    deviceIdKey,
    spaceIdKey,
  };

  final SharedPreferencesWithCache preferences;
  final CloudSecretStorage secretStorage;

  const CloudSyncConfigurationStore({
    required this.preferences,
    required this.secretStorage,
  });

  Future<CloudSyncConfiguration> load() async {
    var deviceId = preferences.getString(deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _newSyncId("device");
      await preferences.setString(deviceIdKey, deviceId);
    }

    final endpoint = preferences.getString(endpointKey) ?? "";
    final provider = _providerFromName(preferences.getString(providerKey));
    return CloudSyncConfiguration(
      provider: provider,
      endpoint: endpoint,
      remoteRoot: preferences.getString(remoteRootKey) ?? "Ciyue",
      username: preferences.getString(usernameKey) ?? "",
      password: switch (provider) {
        CloudSyncProvider.webDav =>
          endpoint.isEmpty
              ? null
              : await secretStorage.read(_webDavPasswordKey),
        CloudSyncProvider.sftp =>
          endpoint.isEmpty ? null : await secretStorage.read(_sftpPasswordKey),
        CloudSyncProvider.s3 => null,
      },
      sftpHostKeyFingerprint: preferences.getString(sftpHostKeyFingerprintKey),
      sftpPrivateKey: endpoint.isEmpty
          ? null
          : await secretStorage.read(_sftpPrivateKeyKey),
      sftpKeyPassphrase: endpoint.isEmpty
          ? null
          : await secretStorage.read(_sftpKeyPassphraseKey),
      s3Bucket: preferences.getString(s3BucketKey),
      s3Region: preferences.getString(s3RegionKey),
      s3AccessKeyId: preferences.getString(s3AccessKeyIdKey),
      s3SecretAccessKey: endpoint.isEmpty
          ? null
          : await secretStorage.read(_s3SecretAccessKeyKey),
      s3UsePathStyle: preferences.getBool(s3UsePathStyleKey) ?? true,
      deviceId: deviceId,
      spaceId: preferences.getString(spaceIdKey),
    );
  }

  Future<CloudSyncConfiguration> saveConnection({
    required CloudSyncConnectionSettings settings,
  }) async {
    final provider = settings.provider;
    final endpoint = settings.endpoint;
    final remoteRoot = settings.remoteRoot;
    final username = settings.username;
    final password = settings.password;
    final sftpHostKeyFingerprint = settings.sftpHostKeyFingerprint;
    final sftpPrivateKey = settings.sftpPrivateKey;
    final sftpKeyPassphrase = settings.sftpKeyPassphrase;
    final s3Bucket = settings.s3Bucket;
    final s3Region = settings.s3Region;
    final s3AccessKeyId = settings.s3AccessKeyId;
    final s3SecretAccessKey = settings.s3SecretAccessKey;
    final s3UsePathStyle = settings.s3UsePathStyle;
    final previousProvider = _providerFromName(
      preferences.getString(providerKey),
    );
    final previousEndpoint = preferences.getString(endpointKey) ?? "";
    final previousRoot = preferences.getString(remoteRootKey) ?? "Ciyue";
    final previousUsername = preferences.getString(usernameKey) ?? "";
    final previousFingerprint = preferences.getString(
      sftpHostKeyFingerprintKey,
    );
    final previousBucket = preferences.getString(s3BucketKey);
    final previousRegion = preferences.getString(s3RegionKey);
    final previousAccessKeyId = preferences.getString(s3AccessKeyIdKey);
    final previousUsePathStyle = preferences.getBool(s3UsePathStyleKey) ?? true;
    final keepSpace =
        previousProvider == provider &&
        previousEndpoint == endpoint &&
        previousRoot == remoteRoot &&
        previousUsername == username &&
        (provider != CloudSyncProvider.sftp ||
            previousFingerprint == sftpHostKeyFingerprint) &&
        (provider != CloudSyncProvider.s3 ||
            (previousBucket == s3Bucket &&
                previousRegion == s3Region &&
                previousAccessKeyId == s3AccessKeyId &&
                previousUsePathStyle == s3UsePathStyle));

    await preferences.setString(providerKey, provider.name);
    await preferences.setString(endpointKey, endpoint);
    await preferences.setString(remoteRootKey, remoteRoot);
    await preferences.setString(usernameKey, username);
    await preferences.setString(
      sftpHostKeyFingerprintKey,
      sftpHostKeyFingerprint ?? "",
    );
    await preferences.setString(s3BucketKey, s3Bucket ?? "");
    await preferences.setString(s3RegionKey, s3Region ?? "");
    await preferences.setString(s3AccessKeyIdKey, s3AccessKeyId ?? "");
    await preferences.setBool(s3UsePathStyleKey, s3UsePathStyle);

    await _saveSecret(
      _webDavPasswordKey,
      provider == CloudSyncProvider.webDav ? password : null,
    );
    await _saveSecret(
      _sftpPasswordKey,
      provider == CloudSyncProvider.sftp ? password : null,
    );
    await _saveSecret(
      _sftpPrivateKeyKey,
      provider == CloudSyncProvider.sftp ? sftpPrivateKey : null,
    );
    await _saveSecret(
      _sftpKeyPassphraseKey,
      provider == CloudSyncProvider.sftp && sftpPrivateKey?.isNotEmpty == true
          ? sftpKeyPassphrase
          : null,
    );
    await _saveSecret(
      _s3SecretAccessKeyKey,
      provider == CloudSyncProvider.s3 ? s3SecretAccessKey : null,
    );

    if (!keepSpace) await preferences.remove(spaceIdKey);
    return load();
  }

  Future<void> _saveSecret(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await secretStorage.delete(key);
    } else {
      await secretStorage.write(key, value);
    }
  }

  Future<void> saveSpaceId(String spaceId) async {
    if (spaceId.isEmpty) throw ArgumentError.value(spaceId, "spaceId");
    await preferences.setString(spaceIdKey, spaceId);
  }

  Future<String?> loadSpaceId() async => preferences.getString(spaceIdKey);

  Future<void> disconnect() async {
    for (final key in preferenceKeys) {
      if (key != deviceIdKey) await preferences.remove(key);
    }
    for (final key in [
      _webDavPasswordKey,
      _sftpPasswordKey,
      _sftpPrivateKeyKey,
      _sftpKeyPassphraseKey,
      _s3SecretAccessKeyKey,
    ]) {
      await secretStorage.delete(key);
    }
  }
}

CloudSyncProvider _providerFromName(String? name) =>
    CloudSyncProvider.values.firstWhere(
      (provider) => provider.name == name,
      orElse: () => CloudSyncProvider.webDav,
    );

String generateCloudSyncSpaceId() => _newSyncId("space");

String _newSyncId(String prefix) {
  final random = Random.secure();
  final hex = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, "0"),
  ).join();
  return "$prefix-$hex";
}

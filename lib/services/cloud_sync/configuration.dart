import "dart:math";

import "package:shared_preferences/shared_preferences.dart";
import "package:simple_secure_storage/simple_secure_storage.dart";

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
  final String endpoint;
  final String remoteRoot;
  final String username;
  final String? password;
  final String deviceId;
  final String? spaceId;

  const CloudSyncConfiguration({
    required this.endpoint,
    required this.remoteRoot,
    required this.username,
    required this.password,
    required this.deviceId,
    required this.spaceId,
  });

  bool get isConfigured => endpoint.isNotEmpty;
}

/// Persists non-secret WebDAV settings in preferences and credentials in the
/// operating system's secure storage.
class CloudSyncConfigurationStore {
  static const endpointKey = "cloudSyncEndpoint";
  static const remoteRootKey = "cloudSyncRemoteRoot";
  static const usernameKey = "cloudSyncUsername";
  static const deviceIdKey = "cloudSyncDeviceId";
  static const spaceIdKey = "cloudSyncSpaceId";
  static const _passwordKey = "ciyue.cloud_sync.webdav.password";

  static const preferenceKeys = {
    endpointKey,
    remoteRootKey,
    usernameKey,
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
    return CloudSyncConfiguration(
      endpoint: endpoint,
      remoteRoot: preferences.getString(remoteRootKey) ?? "Ciyue",
      username: preferences.getString(usernameKey) ?? "",
      password: endpoint.isEmpty
          ? null
          : await secretStorage.read(_passwordKey),
      deviceId: deviceId,
      spaceId: preferences.getString(spaceIdKey),
    );
  }

  Future<CloudSyncConfiguration> saveConnection({
    required String endpoint,
    required String remoteRoot,
    required String username,
    required String password,
  }) async {
    final previousEndpoint = preferences.getString(endpointKey) ?? "";
    final previousRoot = preferences.getString(remoteRootKey) ?? "Ciyue";
    final keepSpace =
        previousEndpoint == endpoint && previousRoot == remoteRoot;

    await preferences.setString(endpointKey, endpoint);
    await preferences.setString(remoteRootKey, remoteRoot);
    await preferences.setString(usernameKey, username);
    if (password.isEmpty) {
      await secretStorage.delete(_passwordKey);
    } else {
      await secretStorage.write(_passwordKey, password);
    }
    if (!keepSpace) await preferences.remove(spaceIdKey);
    return load();
  }

  Future<void> saveSpaceId(String spaceId) async {
    if (spaceId.isEmpty) throw ArgumentError.value(spaceId, "spaceId");
    await preferences.setString(spaceIdKey, spaceId);
  }

  Future<String?> loadSpaceId() async => preferences.getString(spaceIdKey);

  Future<void> disconnect() async {
    await preferences.remove(endpointKey);
    await preferences.remove(remoteRootKey);
    await preferences.remove(usernameKey);
    await preferences.remove(spaceIdKey);
    await secretStorage.delete(_passwordKey);
  }
}

String generateCloudSyncSpaceId() => _newSyncId("space");

String _newSyncId(String prefix) {
  final random = Random.secure();
  final hex = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, "0"),
  ).join();
  return "$prefix-$hex";
}

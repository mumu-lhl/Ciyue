import "dart:math";

import "package:shared_preferences/shared_preferences.dart";
import "package:simple_secure_storage/simple_secure_storage.dart";

enum CloudSyncProvider { webDav, googleDrive, oneDrive }

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
  final CloudSyncProvider provider;
  final bool oauthConnected;
  final String? googleDriveParentFolderId;
  final String? googleDriveParentFolderName;
  final String username;
  final String? password;
  final String deviceId;
  final String? spaceId;

  const CloudSyncConfiguration({
    required this.endpoint,
    required this.remoteRoot,
    this.provider = CloudSyncProvider.webDav,
    this.oauthConnected = false,
    this.googleDriveParentFolderId,
    this.googleDriveParentFolderName,
    required this.username,
    required this.password,
    required this.deviceId,
    required this.spaceId,
  });

  bool get isConfigured => provider == CloudSyncProvider.webDav
      ? endpoint.isNotEmpty
      : oauthConnected;
}

/// Persists the cloud profile in preferences and credentials in the operating
/// system's secure storage.
class CloudSyncConfigurationStore {
  static const endpointKey = "cloudSyncEndpoint";
  static const providerKey = "cloudSyncProvider";
  static const remoteRootKey = "cloudSyncRemoteRoot";
  static const googleDriveParentFolderIdKey =
      "cloudSyncGoogleDriveParentFolderId";
  static const googleDriveParentFolderNameKey =
      "cloudSyncGoogleDriveParentFolderName";
  static const usernameKey = "cloudSyncUsername";
  static const deviceIdKey = "cloudSyncDeviceId";
  static const spaceIdKey = "cloudSyncSpaceId";
  static const _passwordKey = "ciyue.cloud_sync.webdav.password";

  static const preferenceKeys = {
    endpointKey,
    providerKey,
    remoteRootKey,
    googleDriveParentFolderIdKey,
    googleDriveParentFolderNameKey,
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
    final provider = _providerFromName(preferences.getString(providerKey));
    final oauthConnected =
        provider != CloudSyncProvider.webDav &&
        await secretStorage.read(_oauthSecretKey(provider)) != null;
    return CloudSyncConfiguration(
      endpoint: endpoint,
      remoteRoot: preferences.getString(remoteRootKey) ?? "Ciyue",
      provider: provider,
      oauthConnected: oauthConnected,
      googleDriveParentFolderId: preferences.getString(
        googleDriveParentFolderIdKey,
      ),
      googleDriveParentFolderName: preferences.getString(
        googleDriveParentFolderNameKey,
      ),
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
    final previousProvider = _providerFromName(
      preferences.getString(providerKey),
    );
    final previousEndpoint = preferences.getString(endpointKey) ?? "";
    final previousRoot = preferences.getString(remoteRootKey) ?? "Ciyue";
    final keepSpace =
        previousProvider == CloudSyncProvider.webDav &&
        previousEndpoint == endpoint &&
        previousRoot == remoteRoot;

    await preferences.setString(providerKey, CloudSyncProvider.webDav.name);
    await preferences.setString(endpointKey, endpoint);
    await preferences.setString(remoteRootKey, remoteRoot);
    await preferences.remove(googleDriveParentFolderIdKey);
    await preferences.remove(googleDriveParentFolderNameKey);
    await preferences.setString(usernameKey, username);
    if (password.isEmpty) {
      await secretStorage.delete(_passwordKey);
    } else {
      await secretStorage.write(_passwordKey, password);
    }
    if (!keepSpace) await preferences.remove(spaceIdKey);
    return load();
  }

  Future<void> saveOAuthConnection({
    required CloudSyncProvider provider,
    required String remoteRoot,
    String? googleDriveParentFolderId,
    String? googleDriveParentFolderName,
  }) async {
    if (provider == CloudSyncProvider.webDav) {
      throw ArgumentError.value(provider, "provider");
    }
    final previousProvider = _providerFromName(
      preferences.getString(providerKey),
    );
    final previousRoot = preferences.getString(remoteRootKey) ?? "Ciyue";
    final previousFolderId = preferences.getString(
      googleDriveParentFolderIdKey,
    );
    final keepSpace =
        previousProvider == provider &&
        previousRoot == remoteRoot &&
        previousFolderId == googleDriveParentFolderId;

    await preferences.setString(providerKey, provider.name);
    await preferences.setString(remoteRootKey, remoteRoot);
    await preferences.remove(endpointKey);
    await preferences.remove(usernameKey);
    await preferences.remove(googleDriveParentFolderIdKey);
    await preferences.remove(googleDriveParentFolderNameKey);
    if (provider == CloudSyncProvider.googleDrive &&
        googleDriveParentFolderId != null &&
        googleDriveParentFolderId.isNotEmpty) {
      await preferences.setString(
        googleDriveParentFolderIdKey,
        googleDriveParentFolderId,
      );
      if (googleDriveParentFolderName != null &&
          googleDriveParentFolderName.isNotEmpty) {
        await preferences.setString(
          googleDriveParentFolderNameKey,
          googleDriveParentFolderName,
        );
      }
    }
    await secretStorage.delete(_passwordKey);
    if (!keepSpace) await preferences.remove(spaceIdKey);
  }

  Future<void> saveSpaceId(String spaceId) async {
    if (spaceId.isEmpty) throw ArgumentError.value(spaceId, "spaceId");
    await preferences.setString(spaceIdKey, spaceId);
  }

  Future<String?> loadSpaceId() async => preferences.getString(spaceIdKey);

  Future<void> disconnect({bool clearOAuthCredentials = true}) async {
    await preferences.remove(endpointKey);
    await preferences.remove(providerKey);
    await preferences.remove(remoteRootKey);
    await preferences.remove(usernameKey);
    await preferences.remove(googleDriveParentFolderIdKey);
    await preferences.remove(googleDriveParentFolderNameKey);
    await preferences.remove(spaceIdKey);
    await secretStorage.delete(_passwordKey);
    if (clearOAuthCredentials) {
      for (final provider in [
        CloudSyncProvider.googleDrive,
        CloudSyncProvider.oneDrive,
      ]) {
        await secretStorage.delete(_oauthSecretKey(provider));
      }
    }
  }
}

String _oauthSecretKey(CloudSyncProvider provider) =>
    "ciyue.cloud_sync.oauth.${provider == CloudSyncProvider.googleDrive ? "googleDrive" : "oneDrive"}";

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

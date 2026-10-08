import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/cloud_sync/configuration.dart";
import "package:ciyue/services/cloud_sync/coordinator.dart";
import "package:ciyue/services/cloud_sync/dictionary_sync.dart";
import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:ciyue/services/cloud_sync/preview_service.dart";
import "package:ciyue/services/cloud_sync/service.dart";
import "package:ciyue/services/cloud_sync/s3_file_store.dart";
import "package:ciyue/services/cloud_sync/sftp_file_store.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

typedef CloudFileStoreFactory = CloudFileStore Function({
  required CloudSyncConnectionSettings settings,
});

typedef AppSupportDirectoryProvider = Future<Directory> Function();

/// Application-facing operations for previewing, connecting, and syncing one
/// remote profile. The UI does not handle local state paths or cloud-space
/// identity details directly.
class CloudSyncSessionService {
  final AppDatabase database;
  final CloudSyncConfigurationStore configurationStore;
  final CloudSyncPreviewService previewService;
  final CloudSyncSpaceManager spaceManager;
  final DictionarySyncService dictionarySyncService;
  final CloudFileStoreFactory fileStoreFactory;
  final AppSupportDirectoryProvider appSupportDirectoryProvider;

  CloudSyncSessionService({
    required this.database,
    required this.configurationStore,
    CloudSyncPreviewService? previewService,
    this.spaceManager = const CloudSyncSpaceManager(),
    DictionarySyncService? dictionarySyncService,
    CloudFileStoreFactory? fileStoreFactory,
    AppSupportDirectoryProvider? appSupportDirectoryProvider,
  }) : previewService =
           previewService ?? CloudSyncPreviewService(database: database),
       dictionarySyncService =
           dictionarySyncService ?? DictionarySyncService(database: database),
       fileStoreFactory = fileStoreFactory ?? _providerFileStore,
       appSupportDirectoryProvider =
           appSupportDirectoryProvider ?? getApplicationSupportDirectory;

  Future<CloudSyncConfiguration> loadConfiguration() =>
      configurationStore.load();

  Future<CloudSyncPreview> preview({
    required CloudSyncConnectionSettings settings,
  }) async {
    final configuration = await configurationStore.load();
    final normalizedRoot = normalizeCloudSyncRemoteRoot(settings.remoteRoot);
    final normalizedSettings = settings.copyWith(remoteRoot: normalizedRoot);
    final isSameProfile = _isSameProfile(normalizedSettings, configuration);
    final expectedSpaceId = isSameProfile ? configuration.spaceId : null;
    SyncSnapshot? previousLocalSnapshot;
    if (expectedSpaceId != null) {
      previousLocalSnapshot = await fileSyncSnapshotStateStore(
        await appSupportDirectoryProvider(),
        expectedSpaceId,
      ).read();
    }

    final fileStore = _createFileStore(normalizedSettings);
    try {
      final dataPreview = await previewService.preview(
        fileStore: fileStore,
        remoteRoot: normalizedRoot,
        deviceId: configuration.deviceId,
        generatedSpaceId: generateCloudSyncSpaceId(),
        expectedSpaceId: expectedSpaceId,
        previousLocalSnapshot: previousLocalSnapshot,
      );
      final dictionaryPreview = await dictionarySyncService.preview(
        fileStore: fileStore,
        remoteRoot: normalizedRoot,
        remoteFolderExists: dataPreview.remoteFolderExists,
      );
      return CloudSyncPreview(
        remoteFolderExists: dataPreview.remoteFolderExists,
        spaceId: dataPreview.spaceId,
        remoteDeviceCount: dataPreview.remoteDeviceCount,
        local: dataPreview.local,
        remote: dataPreview.remote,
        merged: dataPreview.merged,
        conflicts: dataPreview.conflicts,
        dictionaryPreview: dictionaryPreview,
      );
    } finally {
      await fileStore.close();
    }
  }

  Future<CloudSyncOutcome> connectAndSync({
    required CloudSyncConnectionSettings settings,
    required String previewedSpaceId,
    Set<String> selectedDictionaryPackageIds = const {},
    DictionarySyncPreview? dictionaryPreview,
  }) async {
    final normalizedRoot = normalizeCloudSyncRemoteRoot(settings.remoteRoot);
    final normalizedSettings = settings.copyWith(remoteRoot: normalizedRoot);
    final fileStore = _createFileStore(normalizedSettings);
    try {
      final spaceId = await spaceManager.resolve(
        fileStore: fileStore,
        remoteRoot: normalizedRoot,
        preferredSpaceId: previewedSpaceId,
        generatedSpaceId: previewedSpaceId,
      );
      if (spaceId != previewedSpaceId) {
        throw StateError("Cloud space changed after the preview.");
      }

      await configurationStore.saveConnection(
        settings: CloudSyncConnectionSettings(
          provider: normalizedSettings.provider,
          endpoint: normalizedSettings.endpoint.trim(),
          remoteRoot: normalizedRoot,
          username: normalizedSettings.username.trim(),
          password: normalizedSettings.password,
          sftpHostKeyFingerprint: normalizedSettings.sftpHostKeyFingerprint
              ?.trim(),
          sftpPrivateKey: normalizedSettings.sftpPrivateKey,
          sftpKeyPassphrase: normalizedSettings.sftpKeyPassphrase,
          s3Bucket: normalizedSettings.s3Bucket?.trim(),
          s3Region: normalizedSettings.s3Region?.trim(),
          s3AccessKeyId: normalizedSettings.s3AccessKeyId?.trim(),
          s3SecretAccessKey: normalizedSettings.s3SecretAccessKey,
          s3UsePathStyle: normalizedSettings.s3UsePathStyle,
        ),
      );
      await configurationStore.saveSpaceId(spaceId);
      final outcome = await _syncWithStore(
        configuration: await configurationStore.load(),
        fileStore: fileStore,
        spaceId: spaceId,
      );
      if (selectedDictionaryPackageIds.isNotEmpty) {
        if (dictionaryPreview == null) {
          throw ArgumentError(
            "Selected dictionaries require their preview to be confirmed.",
          );
        }
        final appSupport = await appSupportDirectoryProvider();
        await dictionarySyncService.transferSelected(
          fileStore: fileStore,
          remoteRoot: normalizedRoot,
          preview: dictionaryPreview,
          selectedPackageIds: selectedDictionaryPackageIds,
          dictionaryStorageDirectory: Directory(
            p.join(appSupport.path, "dictionaries"),
          ),
        );
      }
      return outcome;
    } finally {
      await fileStore.close();
    }
  }

  Future<CloudSyncOutcome> syncConfigured() async {
    final configuration = await configurationStore.load();
    if (!configuration.isConfigured || configuration.spaceId == null) {
      throw StateError("Cloud sync has not been connected yet.");
    }

    final fileStore = _createFileStore(
      CloudSyncConnectionSettings(
        provider: configuration.provider,
        endpoint: configuration.endpoint,
        remoteRoot: configuration.remoteRoot,
        username: configuration.username,
        password: configuration.password,
        sftpHostKeyFingerprint: configuration.sftpHostKeyFingerprint,
        sftpPrivateKey: configuration.sftpPrivateKey,
        sftpKeyPassphrase: configuration.sftpKeyPassphrase,
        s3Bucket: configuration.s3Bucket,
        s3Region: configuration.s3Region,
        s3AccessKeyId: configuration.s3AccessKeyId,
        s3SecretAccessKey: configuration.s3SecretAccessKey,
        s3UsePathStyle: configuration.s3UsePathStyle,
      ),
    );
    try {
      final spaceId = await spaceManager.resolve(
        fileStore: fileStore,
        remoteRoot: configuration.remoteRoot,
        preferredSpaceId: configuration.spaceId,
        generatedSpaceId: configuration.spaceId!,
      );
      return await _syncWithStore(
        configuration: configuration,
        fileStore: fileStore,
        spaceId: spaceId,
      );
    } finally {
      await fileStore.close();
    }
  }

  Future<void> disconnect() => configurationStore.disconnect();

  Future<void> rebindSpace(String newSpaceId) =>
      configurationStore.saveSpaceId(newSpaceId);

  Future<CloudSyncOutcome> _syncWithStore({
    required CloudSyncConfiguration configuration,
    required CloudFileStore fileStore,
    required String spaceId,
  }) async {
    final appSupport = await appSupportDirectoryProvider();
    final syncService = CloudSyncService(
      database: database,
      deviceId: configuration.deviceId,
      spaceId: spaceId,
      remoteRoot: configuration.remoteRoot,
      fileStore: fileStore,
      stateStore: fileSyncSnapshotStateStore(appSupport, spaceId),
    );
    return syncService.sync();
  }

  CloudFileStore _createFileStore(CloudSyncConnectionSettings settings) {
    if (settings.provider == CloudSyncProvider.webDav) {
      final hasUsername = settings.username.trim().isNotEmpty;
      final hasPassword =
          settings.password != null && settings.password!.isNotEmpty;
      if (hasUsername != hasPassword) {
        throw ArgumentError(
          "WebDAV username and password must be supplied together.",
        );
      }
    }
    return fileStoreFactory(settings: settings);
  }

  bool _isSameProfile(
    CloudSyncConnectionSettings settings,
    CloudSyncConfiguration configuration,
  ) =>
      settings.provider == configuration.provider &&
      settings.endpoint.trim() == configuration.endpoint &&
      settings.remoteRoot == configuration.remoteRoot &&
      settings.username.trim() == configuration.username &&
      switch (settings.provider) {
        CloudSyncProvider.webDav => true,
        CloudSyncProvider.sftp =>
          settings.sftpHostKeyFingerprint?.trim() ==
              configuration.sftpHostKeyFingerprint,
        CloudSyncProvider.s3 =>
          settings.s3Bucket?.trim() == configuration.s3Bucket &&
              settings.s3Region?.trim() == configuration.s3Region &&
              settings.s3AccessKeyId?.trim() == configuration.s3AccessKeyId &&
              settings.s3UsePathStyle == configuration.s3UsePathStyle,
      };
}

CloudFileStore _providerFileStore({
  required CloudSyncConnectionSettings settings,
}) => switch (settings.provider) {
  CloudSyncProvider.webDav => WebDavCloudFileStore(
    baseUri: Uri.parse(settings.endpoint.trim()),
    username: settings.username.trim().isEmpty
        ? null
        : settings.username.trim(),
    password: settings.password,
  ),
  CloudSyncProvider.sftp => SftpCloudFileStore(
    endpoint: Uri.parse(settings.endpoint.trim()),
    username: settings.username.trim(),
    password: settings.password,
    privateKey: settings.sftpPrivateKey,
    keyPassphrase: settings.sftpKeyPassphrase,
    expectedHostKeyFingerprint: settings.sftpHostKeyFingerprint ?? "",
  ),
  CloudSyncProvider.s3 => S3CloudFileStore(
    endpoint: Uri.parse(settings.endpoint.trim()),
    bucket: settings.s3Bucket ?? "",
    remoteRoot: settings.remoteRoot,
    region: settings.s3Region ?? "",
    accessKeyId: settings.s3AccessKeyId ?? "",
    secretAccessKey: settings.s3SecretAccessKey ?? "",
    usePathStyle: settings.s3UsePathStyle,
  ),
};

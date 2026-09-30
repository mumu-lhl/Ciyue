import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/cloud_sync/configuration.dart";
import "package:ciyue/services/cloud_sync/coordinator.dart";
import "package:ciyue/services/cloud_sync/dictionary_sync.dart";
import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:ciyue/services/cloud_sync/preview_service.dart";
import "package:ciyue/services/cloud_sync/service.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

typedef CloudFileStoreFactory = CloudFileStore Function({
  required Uri baseUri,
  String? username,
  String? password,
});

typedef AppSupportDirectoryProvider = Future<Directory> Function();

/// Application-facing operations for previewing, connecting, and syncing one
/// WebDAV profile. The UI does not handle credentials, local state paths, or
/// cloud-space identity details directly.
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
       fileStoreFactory = fileStoreFactory ?? _webDavFileStore,
       appSupportDirectoryProvider =
           appSupportDirectoryProvider ?? getApplicationSupportDirectory;

  Future<CloudSyncConfiguration> loadConfiguration() =>
      configurationStore.load();

  Future<CloudSyncPreview> preview({
    required String endpoint,
    required String remoteRoot,
    required String username,
    required String? password,
  }) async {
    final configuration = await configurationStore.load();
    final normalizedRoot = normalizeCloudSyncRemoteRoot(remoteRoot);
    final isSameProfile =
        endpoint.trim() == configuration.endpoint &&
        normalizedRoot == configuration.remoteRoot;
    final expectedSpaceId = isSameProfile ? configuration.spaceId : null;
    SyncSnapshot? previousLocalSnapshot;
    if (expectedSpaceId != null) {
      previousLocalSnapshot = await fileSyncSnapshotStateStore(
        await appSupportDirectoryProvider(),
        expectedSpaceId,
      ).read();
    }

    final fileStore = _createFileStore(
      endpoint: endpoint,
      username: username,
      password: password,
    );
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
    required String endpoint,
    required String remoteRoot,
    required String username,
    required String? password,
    required String previewedSpaceId,
    Set<String> selectedDictionaryPackageIds = const {},
    DictionarySyncPreview? dictionaryPreview,
  }) async {
    final normalizedRoot = normalizeCloudSyncRemoteRoot(remoteRoot);
    final fileStore = _createFileStore(
      endpoint: endpoint,
      username: username,
      password: password,
    );
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
        endpoint: endpoint.trim(),
        remoteRoot: normalizedRoot,
        username: username.trim(),
        password: password ?? "",
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
      throw StateError("WebDAV cloud sync has not been connected yet.");
    }

    final fileStore = _createFileStore(
      endpoint: configuration.endpoint,
      username: configuration.username,
      password: configuration.password,
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

  CloudFileStore _createFileStore({
    required String endpoint,
    required String username,
    required String? password,
  }) {
    final hasUsername = username.trim().isNotEmpty;
    final hasPassword = password != null && password.isNotEmpty;
    if (hasUsername != hasPassword) {
      throw ArgumentError(
        "WebDAV username and password must be supplied together.",
      );
    }
    return fileStoreFactory(
      baseUri: Uri.parse(endpoint.trim()),
      username: hasUsername ? username.trim() : null,
      password: hasPassword ? password : null,
    );
  }
}

CloudFileStore _webDavFileStore({
  required Uri baseUri,
  String? username,
  String? password,
}) => WebDavCloudFileStore(
  baseUri: baseUri,
  username: username,
  password: password,
);

import "dart:convert";
import "dart:io";

import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:path/path.dart" as p;

class CloudSyncOutcome {
  final SyncSnapshot snapshot;
  final List<SyncConflict> conflicts;
  final int remoteDeviceCount;
  final bool uploaded;

  CloudSyncOutcome({
    required this.snapshot,
    required List<SyncConflict> conflicts,
    required this.remoteDeviceCount,
    required this.uploaded,
  }) : conflicts = List.unmodifiable(conflicts);
}

/// Coordinates device-scoped snapshot exchange over a [CloudFileStore].
///
/// Each device writes only its own file. Concurrent devices therefore don't
/// race to overwrite one shared manifest; the next sync unions their immutable
/// record versions and reports divergent heads as conflicts.
class CloudSyncSpaceManager {
  static const _formatVersion = 1;

  const CloudSyncSpaceManager();

  Future<String> resolve({
    required CloudFileStore fileStore,
    required String remoteRoot,
    required String? preferredSpaceId,
    required String generatedSpaceId,
  }) async {
    final root = normalizeCloudSyncRemoteRoot(remoteRoot);
    final syncRoot = p.posix.join(root, "sync");
    await fileStore.ensureDirectory(syncRoot);
    final manifestPath = p.posix.join(syncRoot, "space.json");
    final manifest = (await fileStore.listDirectory(syncRoot))
        .where((entry) => !entry.isDirectory && entry.name == "space.json")
        .firstOrNull;
    if (manifest != null) {
      final content = await _downloadText(fileStore, manifest.path);
      final decoded = jsonDecode(content);
      if (decoded is! Map ||
          decoded["app"] != "ciyue" ||
          decoded["formatVersion"] != _formatVersion ||
          decoded["spaceId"] is! String ||
          (decoded["spaceId"] as String).isEmpty) {
        throw const FormatException("Invalid Ciyue cloud-space manifest.");
      }
      final cloudSpaceId = decoded["spaceId"] as String;
      if (preferredSpaceId != null && preferredSpaceId != cloudSpaceId) {
        throw StateError(
          "This local sync state belongs to '$preferredSpaceId', "
          "but the selected cloud folder belongs to '$cloudSpaceId'.",
        );
      }
      return cloudSpaceId;
    }

    final spaceId = preferredSpaceId ?? generatedSpaceId;
    if (spaceId.isEmpty) {
      throw ArgumentError.value(spaceId, "spaceId");
    }
    final directory = await Directory.systemTemp.createTemp("ciyue-space-");
    try {
      final file = File(p.join(directory.path, "space.json"));
      await file.writeAsString(
        jsonEncode({
          "app": "ciyue",
          "formatVersion": _formatVersion,
          "spaceId": spaceId,
          "createdAt": DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
      await fileStore.uploadFile(manifestPath, file);
    } finally {
      await directory.delete(recursive: true);
    }
    return spaceId;
  }
}

class CloudSyncCoordinator {
  final CloudSyncEngine engine;
  bool _isSyncing = false;

  CloudSyncCoordinator({this.engine = const CloudSyncEngine()});

  Future<CloudSyncOutcome> sync({
    required CloudFileStore fileStore,
    required String remoteRoot,
    required SyncSnapshot localSnapshot,
  }) async {
    if (_isSyncing) {
      throw StateError("A Ciyue cloud sync is already running.");
    }
    _isSyncing = true;
    try {
      final root = normalizeCloudSyncRemoteRoot(remoteRoot);
      if (!_validDeviceId(localSnapshot.deviceId)) {
        throw ArgumentError.value(localSnapshot.deviceId, "deviceId");
      }
      final devicesPath = p.posix.join(root, "sync", "devices");
      await fileStore.ensureDirectory(devicesPath);

      var mergedSnapshot = localSnapshot;
      var conflicts = <SyncConflict>[];
      var remoteDeviceCount = 0;
      final remoteDevices = await fileStore.listDirectory(devicesPath);
      final snapshotFiles =
          remoteDevices
              .where(
                (entry) =>
                    !entry.isDirectory &&
                    entry.name.endsWith(".json") &&
                    _validDeviceId(
                      entry.name.substring(0, entry.name.length - 5),
                    ),
              )
              .toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name));

      final temporaryDirectory = await Directory.systemTemp.createTemp(
        "ciyue-sync-",
      );
      try {
        for (var index = 0; index < snapshotFiles.length; index++) {
          final entry = snapshotFiles[index];
          final downloaded = File(
            p.join(temporaryDirectory.path, "$index.json"),
          );
          await fileStore.downloadFile(entry.path, downloaded);
          final remoteSnapshot = SyncSnapshot.decode(
            await downloaded.readAsString(),
          );
          final expectedDeviceId = entry.name.substring(
            0,
            entry.name.length - 5,
          );
          if (remoteSnapshot.deviceId != expectedDeviceId) {
            throw FormatException(
              "Sync file '${entry.name}' contains a different device ID.",
            );
          }
          final result = engine.merge(mergedSnapshot, remoteSnapshot);
          mergedSnapshot = result.snapshot;
          conflicts = result.conflicts;
          remoteDeviceCount++;
        }

        final ownRemotePath = p.posix.join(
          devicesPath,
          "${localSnapshot.deviceId}.json",
        );
        final ownSnapshot = snapshotFiles
            .where((entry) => entry.name == "${localSnapshot.deviceId}.json")
            .firstOrNull;
        final serialized = mergedSnapshot.encode();
        var uploaded = true;
        if (ownSnapshot != null) {
          final existingFile = File(
            p.join(temporaryDirectory.path, "existing-own.json"),
          );
          await fileStore.downloadFile(ownSnapshot.path, existingFile);
          final existingContent = await existingFile.readAsString();
          if (_canonicalJson(existingContent) == _canonicalJson(serialized)) {
            uploaded = false;
          }
        }

        if (uploaded) {
          final snapshotFile = File(
            p.join(temporaryDirectory.path, "${localSnapshot.deviceId}.json"),
          );
          await snapshotFile.writeAsString(serialized, flush: true);
          await fileStore.uploadFile(ownRemotePath, snapshotFile);
        }

        return CloudSyncOutcome(
          snapshot: mergedSnapshot,
          conflicts: conflicts,
          remoteDeviceCount: remoteDeviceCount,
          uploaded: uploaded,
        );
      } finally {
        await temporaryDirectory.delete(recursive: true);
      }
    } finally {
      _isSyncing = false;
    }
  }
}

String normalizeCloudSyncRemoteRoot(String remoteRoot) {
  final segments = remoteRoot
      .trim()
      .replaceAll("\\", "/")
      .split("/")
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty ||
      segments.any(
        (segment) =>
            segment == "." ||
            segment == ".." ||
            segment.contains("\u0000") ||
            segment.contains(":") ||
            segment.contains("%2f") ||
            segment.contains("%2F"),
      )) {
    throw ArgumentError.value(
      remoteRoot,
      "remoteRoot",
      "Unsafe cloud folder path",
    );
  }
  return p.posix.joinAll(segments);
}

bool _validDeviceId(String deviceId) =>
    deviceId.isNotEmpty && RegExp(r"^[A-Za-z0-9_-]+$").hasMatch(deviceId);

String _canonicalJson(String content) {
  final decoded = jsonDecode(content);
  return jsonEncode(_canonicalizeJson(decoded));
}

Object? _canonicalizeJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key as String).toList()..sort();
    return {for (final key in keys) key: _canonicalizeJson(value[key])};
  }
  if (value is List) {
    return value.map(_canonicalizeJson).toList(growable: false);
  }
  return value;
}

Future<String> _downloadText(
  CloudFileStore fileStore,
  String remotePath,
) async {
  final directory = await Directory.systemTemp.createTemp("ciyue-space-read-");
  try {
    final file = File(p.join(directory.path, "space.json"));
    await fileStore.downloadFile(remotePath, file);
    return await file.readAsString();
  } finally {
    await directory.delete(recursive: true);
  }
}

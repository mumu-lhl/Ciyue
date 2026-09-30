import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart" show ProgressCallback;
import "package:http/http.dart" as http;
import "package:s3_client/s3_client.dart";

import "file_store.dart";

/// S3-compatible object storage implementation using Signature Version 4.
///
/// Directory markers are written only when sync is confirmed and a directory
/// is first needed. Object uploads are staged, copied to their final key, and
/// then cleaned up so interrupted transfers cannot expose partial snapshots.
class S3CloudFileStore implements CloudFileStore {
  final Uri endpoint;
  final String bucket;
  final String remoteRoot;
  final String region;
  final String accessKeyId;
  final String secretAccessKey;
  final bool usePathStyle;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final S3Client _client;
  final Set<String> _ensuredDirectories = {};
  int _temporaryFileCounter = 0;

  factory S3CloudFileStore({
    required Uri endpoint,
    required String bucket,
    String remoteRoot = "Ciyue",
    required String region,
    required String accessKeyId,
    required String secretAccessKey,
    bool usePathStyle = true,
    http.Client? httpClient,
  }) {
    if (bucket.trim().isEmpty || bucket.contains("/")) {
      throw ArgumentError.value(bucket, "bucket");
    }
    if (region.trim().isEmpty) throw ArgumentError.value(region, "region");
    if (accessKeyId.isEmpty || secretAccessKey.isEmpty) {
      throw ArgumentError("S3 access key ID and secret are required.");
    }
    final safeRemoteRoot = _cleanS3Path(remoteRoot);
    if (safeRemoteRoot.isEmpty) {
      throw ArgumentError.value(remoteRoot, "remoteRoot");
    }
    final validatedEndpoint = _validateEndpoint(endpoint, usePathStyle);
    final transport = httpClient ?? http.Client();
    final client = S3Client(
      baseEndpoint: validatedEndpoint,
      credentials: S3CredentialsProvider.static(
        accessKeyId: accessKeyId,
        secretAccessKey: secretAccessKey,
      ),
      region: region,
      usePathStyle: usePathStyle,
      httpClient: transport,
    );
    return S3CloudFileStore._(
      endpoint: endpoint,
      bucket: bucket,
      remoteRoot: safeRemoteRoot,
      region: region,
      accessKeyId: accessKeyId,
      secretAccessKey: secretAccessKey,
      usePathStyle: usePathStyle,
      httpClient: transport,
      ownsHttpClient: httpClient == null,
      client: client,
    );
  }

  S3CloudFileStore._({
    required this.endpoint,
    required this.bucket,
    required this.remoteRoot,
    required this.region,
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.usePathStyle,
    required this._httpClient,
    required this._ownsHttpClient,
    required this._client,
  });

  static Uri _validateEndpoint(Uri endpoint, bool usePathStyle) {
    if (endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        (endpoint.scheme != "https" &&
            !(endpoint.scheme == "http" && _isLoopbackHost(endpoint.host)))) {
      throw ArgumentError.value(
        endpoint,
        "endpoint",
        "S3 endpoint must use HTTPS (HTTP is allowed only for localhost).",
      );
    }
    if (!usePathStyle && endpoint.pathSegments.isNotEmpty) {
      throw ArgumentError.value(
        endpoint,
        "endpoint",
        "Virtual-hosted addressing does not support an endpoint path prefix.",
      );
    }
    return endpoint;
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == "localhost") return true;
    final address = InternetAddress.tryParse(normalized);
    return address?.isLoopback == true;
  }

  String _cleanPath(String remotePath) => _cleanS3Path(remotePath);

  @override
  Future<List<CloudFileEntry>> listDirectory(String remotePath) async {
    final path = _cleanPath(remotePath);
    if (path.isEmpty) {
      final root = _cleanPath(remoteRoot);
      final prefix = "$root/";
      await for (final page in _client.listObjectsV2(
        bucket: bucket,
        prefix: prefix,
        delimiter: "/",
        maxKeys: 1,
      )) {
        if (page.contents.isEmpty && page.commonPrefixes.isEmpty) continue;
        return [
          CloudFileEntry(
            name: root.split("/").last,
            path: root,
            isDirectory: true,
          ),
        ];
      }
      return const [];
    }
    final prefix = "$path/";
    final entries = <String, CloudFileEntry>{};
    await for (final page in _client.listObjectsV2(
      bucket: bucket,
      prefix: prefix,
      delimiter: "/",
    )) {
      for (final object in page.contents) {
        final key = object.key;
        if (key == prefix || !key.startsWith(prefix)) continue;
        final rest = key.substring(prefix.length);
        if (rest.isEmpty || rest.contains("/")) continue;
        if (!_isSafeSegment(rest)) continue;
        entries[key] = CloudFileEntry(
          name: rest,
          path: key,
          isDirectory: false,
          sizeBytes: object.size,
        );
      }
      for (final commonPrefix in page.commonPrefixes) {
        if (!commonPrefix.startsWith(prefix)) continue;
        final remainder = commonPrefix.substring(prefix.length);
        final name = remainder.replaceFirst(RegExp(r"/+$"), "");
        if (name.isEmpty || name.contains("/")) continue;
        if (!_isSafeSegment(name)) continue;
        final childPath = path.isEmpty ? name : "$path/$name";
        entries[childPath] = CloudFileEntry(
          name: name,
          path: childPath,
          isDirectory: true,
        );
      }
    }
    final result = entries.values.toList();
    result.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  bool _isSafeSegment(String segment) =>
      segment.isNotEmpty &&
      segment != "." &&
      segment != ".." &&
      !segment.contains("\\") &&
      !segment.contains("\u0000");

  @override
  Future<void> ensureDirectory(String remotePath) async {
    final path = _cleanPath(remotePath);
    if (path.isEmpty) return;
    var current = "";
    for (final segment in path.split("/")) {
      current = current.isEmpty ? segment : "$current/$segment";
      final markerKey = "$current/";
      if (!_ensuredDirectories.contains(current)) {
        await _client.putObject(
          bucket: bucket,
          key: markerKey,
          body: Stream<Uint8List>.value(Uint8List(0)),
          contentLength: 0,
        );
        _ensuredDirectories.add(current);
      }
    }
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    File destination, {
    ProgressCallback? onReceiveProgress,
  }) async {
    final key = _cleanPath(remotePath);
    if (key.isEmpty) throw ArgumentError.value(remotePath, "remotePath");
    await destination.parent.create(recursive: true);
    final temporary = File("${destination.path}.ciyue-download");
    if (await temporary.exists()) await temporary.delete();
    try {
      final object = await _client.getObject(bucket: bucket, key: key);
      final sink = temporary.openWrite();
      var received = 0;
      try {
        await for (final chunk in object) {
          sink.add(chunk);
          received += chunk.length;
          onReceiveProgress?.call(received, object.contentLength ?? -1);
        }
        await sink.close();
      } catch (_) {
        await sink.close();
        rethrow;
      }
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  @override
  Future<void> uploadFile(
    String remotePath,
    File source, {
    ProgressCallback? onSendProgress,
  }) async {
    final key = _cleanPath(remotePath);
    if (key.isEmpty) throw ArgumentError.value(remotePath, "remotePath");
    if (!await source.exists()) {
      throw FileSystemException("Source file not found", source.path);
    }
    final parent = key.contains("/")
        ? key.substring(0, key.lastIndexOf("/"))
        : "";
    if (parent.isNotEmpty) await ensureDirectory(parent);

    _temporaryFileCounter++;
    final temporaryKey =
        ".ciyue-tmp-${DateTime.now().microsecondsSinceEpoch}-$_temporaryFileCounter";
    final size = await source.length();
    try {
      await _client.putObject(
        bucket: bucket,
        key: temporaryKey,
        body: _withProgress(source.openRead(), size, onSendProgress),
        contentLength: size,
      );
      await _client.copyObject(
        bucket: bucket,
        key: key,
        copySource: "$bucket/$temporaryKey",
      );
    } catch (_) {
      try {
        await _client.deleteObject(bucket: bucket, key: temporaryKey);
      } on Object {
        // Best effort cleanup of an interrupted staging object.
      }
      rethrow;
    }
    try {
      await _client.deleteObject(bucket: bucket, key: temporaryKey);
    } on Object {
      // A copied object is already complete; an orphaned staging object is safe.
    }
  }

  Stream<Uint8List> _withProgress(
    Stream<List<int>> source,
    int total,
    ProgressCallback? onProgress,
  ) async* {
    var sent = 0;
    await for (final chunk in source) {
      sent += chunk.length;
      onProgress?.call(sent, total);
      yield Uint8List.fromList(chunk);
    }
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    final key = _cleanPath(remotePath);
    if (key.isEmpty) throw ArgumentError.value(remotePath, "remotePath");
    await _client.deleteObject(bucket: bucket, key: key);
  }

  @override
  Future<void> close() async {
    if (_ownsHttpClient) _httpClient.close();
  }
}

String _cleanS3Path(String path) {
  if (path.contains("\\") || path.contains("\u0000")) {
    throw ArgumentError.value(path, "path");
  }
  final segments = path.split("/");
  if (segments.any((segment) => segment == "." || segment == "..")) {
    throw ArgumentError.value(path, "path");
  }
  return segments.where((segment) => segment.isNotEmpty).join("/");
}

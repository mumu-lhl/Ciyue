import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";

import "file_store.dart";

/// Microsoft Graph adapter using the delegated `Files.ReadWrite` permission.
///
/// Uploads use Graph upload sessions so large dictionary files are streamed in
/// resumable-sized ranges. Session URLs are pre-authorized and are never sent
/// the user's Graph bearer token.
class OneDriveCloudFileStore implements CloudFileStore {
  static const _chunkSize = 10 * 320 * 1024;

  final CloudAccessTokenProvider accessTokenProvider;
  final Dio _dio;
  final bool _ownsDio;
  final Uri apiBaseUri;

  OneDriveCloudFileStore({
    required this.accessTokenProvider,
    Dio? dio,
    Uri? apiBaseUri,
  }) : apiBaseUri = apiBaseUri ?? Uri.https("graph.microsoft.com", "/v1.0/"),
       _dio = dio ?? Dio(),
       _ownsDio = dio == null;

  @override
  Future<List<CloudFileEntry>> listDirectory(String remotePath) async {
    final path = _cleanPath(remotePath);
    final response = await _request("GET", _childrenUri(path));
    if (response.statusCode == HttpStatus.notFound) return const [];
    _requireSuccess(response, "OneDrive list", path);
    final entries = <CloudFileEntry>[];
    var body = _decodeMap(response.data);
    while (true) {
      final values = body["value"];
      if (values is List) {
        for (final rawItem in values) {
          if (rawItem is! Map) continue;
          final item = Map<String, dynamic>.from(rawItem);
          final name = item["name"];
          if (name is! String || name.isEmpty) continue;
          final isDirectory = item["folder"] is Map;
          final size = item["size"];
          entries.add(
            CloudFileEntry(
              name: name,
              path: path.isEmpty ? name : "$path/$name",
              isDirectory: isDirectory,
              sizeBytes: size is int
                  ? size
                  : int.tryParse(size?.toString() ?? ""),
            ),
          );
        }
      }
      final nextLink = body["@odata.nextLink"];
      if (nextLink is! String || nextLink.isEmpty) break;
      final nextUri = Uri.tryParse(nextLink);
      if (nextUri == null ||
          nextUri.scheme != apiBaseUri.scheme ||
          nextUri.host != apiBaseUri.host ||
          nextUri.port != apiBaseUri.port) {
        throw const FormatException(
          "Graph returned an invalid pagination URL.",
        );
      }
      final nextResponse = await _requestUri("GET", nextUri);
      _requireSuccess(nextResponse, "OneDrive list", path);
      body = _decodeMap(nextResponse.data);
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  @override
  Future<void> ensureDirectory(String remotePath) async {
    var parentPath = "";
    for (final segment in _segments(remotePath)) {
      final directoryPath = parentPath.isEmpty
          ? segment
          : "$parentPath/$segment";
      final existing = await _getItem(directoryPath);
      if (existing != null) {
        if (existing["folder"] is! Map) {
          throw FileSystemException(
            "A file blocks the cloud folder path",
            directoryPath,
          );
        }
        parentPath = directoryPath;
        continue;
      }

      final response = await _request(
        "POST",
        _childrenUri(parentPath),
        data: {
          "name": segment,
          "folder": <String, Object?>{},
          "@microsoft.graph.conflictBehavior": "fail",
        },
      );
      if (response.statusCode == HttpStatus.conflict) {
        final racedItem = await _getItem(directoryPath);
        if (racedItem != null && racedItem["folder"] is Map) {
          parentPath = directoryPath;
          continue;
        }
      }
      _requireSuccess(response, "OneDrive create folder", directoryPath);
      parentPath = directoryPath;
    }
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    File destination, {
    ProgressCallback? onReceiveProgress,
  }) async {
    final path = _cleanPath(remotePath);
    if (path.isEmpty) throw ArgumentError.value(remotePath, "remotePath");
    final item = await _getItem(path);
    if (item == null || item["file"] is! Map) {
      throw FileSystemException("OneDrive file not found", path);
    }
    final itemId = _requiredId(item);
    final metadataResponse = await _request("GET", _itemByIdUri(itemId));
    _requireSuccess(metadataResponse, "OneDrive download", path);
    final downloadUrl = _decodeMap(
      metadataResponse.data,
    )["@microsoft.graph.downloadUrl"];
    if (downloadUrl is! String || downloadUrl.isEmpty) {
      throw const FormatException("Graph did not return a download URL.");
    }

    final temporary = File("${destination.path}.ciyue-download");
    await destination.parent.create(recursive: true);
    if (await temporary.exists()) await temporary.delete();
    try {
      final response = await _dio.downloadUri(
        Uri.parse(downloadUrl),
        temporary.path,
        onReceiveProgress: onReceiveProgress,
        deleteOnError: true,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw _httpError("OneDrive download", path, response.statusCode);
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
    final path = _cleanPath(remotePath);
    if (path.isEmpty) throw ArgumentError.value(remotePath, "remotePath");
    if (!await source.exists()) {
      throw FileSystemException("Source file not found", source.path);
    }
    final segments = _segments(path);
    final name = segments.removeLast();
    final parentPath = segments.join("/");
    if (parentPath.isNotEmpty) await ensureDirectory(parentPath);
    final existing = await _getItem(path);
    if (existing != null && existing["folder"] is Map) {
      throw FileSystemException("A folder blocks the cloud file path", path);
    }

    final fileLength = await source.length();
    if (fileLength == 0) {
      final uri = existing == null
          ? _contentUri(path)
          : _contentByIdUri(_requiredId(existing));
      final response = await _request(
        "PUT",
        uri,
        data: Uint8List(0),
        contentLength: 0,
        contentType: "application/octet-stream",
      );
      _requireUploadSuccess(response, "OneDrive upload", path);
      onSendProgress?.call(0, 0);
      return;
    }

    final sessionResponse = await _request(
      "POST",
      existing == null
          ? _uploadSessionUri(path)
          : _uploadSessionByIdUri(_requiredId(existing)),
      data: {
        "item": {
          "@microsoft.graph.conflictBehavior": existing == null
              ? "fail"
              : "replace",
          "name": name,
        },
      },
    );
    _requireSuccess(sessionResponse, "OneDrive create upload session", path);
    final uploadUrl = _decodeMap(sessionResponse.data)["uploadUrl"];
    if (uploadUrl is! String || uploadUrl.isEmpty) {
      throw const FormatException("Graph did not return an upload URL.");
    }
    final uploadUri = Uri.parse(uploadUrl);
    if (uploadUri.scheme != "https" && !_isLoopbackHost(uploadUri.host)) {
      throw const FormatException("Graph returned an unsafe upload URL.");
    }

    for (var start = 0; start < fileLength; start += _chunkSize) {
      final endExclusive = (start + _chunkSize).clamp(0, fileLength);
      final chunkLength = endExclusive - start;
      final response = await _dio.putUri<dynamic>(
        uploadUri,
        data: source.openRead(start, endExclusive),
        onSendProgress: (sent, _) => onSendProgress?.call(
          start + sent.clamp(0, chunkLength),
          fileLength,
        ),
        options: Options(
          headers: {
            HttpHeaders.contentLengthHeader: chunkLength,
            HttpHeaders.contentRangeHeader:
                "bytes $start-${endExclusive - 1}/$fileLength",
            HttpHeaders.contentTypeHeader: "application/octet-stream",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode != HttpStatus.accepted &&
          response.statusCode != HttpStatus.created &&
          response.statusCode != HttpStatus.ok) {
        throw _httpError("OneDrive upload", path, response.statusCode);
      }
      if (endExclusive == fileLength &&
          response.statusCode == HttpStatus.accepted) {
        throw const HttpException("OneDrive upload session did not complete.");
      }
    }
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    final path = _cleanPath(remotePath);
    if (path.isEmpty) throw ArgumentError.value(remotePath, "remotePath");
    final item = await _getItem(path);
    if (item == null) return;
    if (item["folder"] is Map) {
      throw FileSystemException("Refusing to delete a cloud directory", path);
    }
    final response = await _request("DELETE", _itemByIdUri(_requiredId(item)));
    if (response.statusCode != HttpStatus.noContent &&
        response.statusCode != HttpStatus.ok) {
      throw _httpError("OneDrive delete", path, response.statusCode);
    }
  }

  @override
  Future<void> close() async {
    if (_ownsDio) _dio.close(force: true);
  }

  Future<Map<String, dynamic>?> _getItem(String path) async {
    final response = await _request("GET", _itemUri(_cleanPath(path)));
    if (response.statusCode == HttpStatus.notFound) return null;
    _requireSuccess(response, "OneDrive lookup", path);
    return _decodeMap(response.data);
  }

  Future<Response<dynamic>> _request(
    String method,
    Uri uri, {
    Map<String, String>? queryParameters,
    Object? data,
    int? contentLength,
    String? contentType,
  }) async {
    final target = queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
    return _requestUri(
      method,
      target,
      data: data,
      contentLength: contentLength,
      contentType: contentType,
    );
  }

  Future<Response<dynamic>> _requestUri(
    String method,
    Uri uri, {
    Object? data,
    int? contentLength,
    String? contentType,
  }) async {
    final token = await accessTokenProvider();
    return _dio.requestUri<dynamic>(
      uri,
      data: data,
      options: Options(
        method: method,
        headers: {
          HttpHeaders.authorizationHeader: "Bearer $token",
          ...?contentLength == null
              ? null
              : {HttpHeaders.contentLengthHeader: contentLength},
          ...?contentType == null
              ? null
              : {HttpHeaders.contentTypeHeader: contentType},
        },
        contentType: data is Map ? Headers.jsonContentType : contentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  Uri _childrenUri(String path) => path.isEmpty
      ? apiBaseUri.resolve("me/drive/root/children")
      : apiBaseUri.resolve("me/drive/root:/${_encodePath(path)}:/children");

  Uri _itemUri(String path) => path.isEmpty
      ? apiBaseUri.resolve("me/drive/root")
      : apiBaseUri.resolve("me/drive/root:/${_encodePath(path)}");

  Uri _contentUri(String path) =>
      apiBaseUri.resolve("me/drive/root:/${_encodePath(path)}:/content");

  Uri _uploadSessionUri(String path) => apiBaseUri.resolve(
    "me/drive/root:/${_encodePath(path)}:/createUploadSession",
  );

  Uri _contentByIdUri(String id) =>
      apiBaseUri.resolve("me/drive/items/${Uri.encodeComponent(id)}/content");

  Uri _uploadSessionByIdUri(String id) => apiBaseUri.resolve(
    "me/drive/items/${Uri.encodeComponent(id)}/createUploadSession",
  );

  Uri _itemByIdUri(String id) =>
      apiBaseUri.resolve("me/drive/items/${Uri.encodeComponent(id)}");

  static String _encodePath(String path) =>
      _segments(path).map(Uri.encodeComponent).join("/");

  static String _cleanPath(String path) {
    final normalized = path.trim().replaceAll("\\", "/");
    final segments = normalized.split("/").where((part) => part.isNotEmpty);
    for (final segment in segments) {
      if (segment == "." || segment == ".." || segment.contains("\u0000")) {
        throw ArgumentError.value(path, "remotePath", "Unsafe cloud file path");
      }
    }
    return segments.join("/");
  }

  static List<String> _segments(String path) {
    final clean = _cleanPath(path);
    return clean.isEmpty ? <String>[] : clean.split("/");
  }

  static Map<String, dynamic> _decodeMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException("Graph returned an invalid JSON response.");
  }

  static String _requiredId(Map<String, dynamic> item) {
    final id = item["id"];
    if (id is! String || id.isEmpty) {
      throw const FormatException("Graph response did not include an item ID.");
    }
    return id;
  }

  static void _requireSuccess(
    Response<dynamic> response,
    String operation,
    String path,
  ) {
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw _httpError(operation, path, response.statusCode);
    }
  }

  static void _requireUploadSuccess(
    Response<dynamic> response,
    String operation,
    String path,
  ) {
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.created) {
      throw _httpError(operation, path, response.statusCode);
    }
  }

  static bool _isLoopbackHost(String host) =>
      host == "localhost" ||
      host == "::1" ||
      host == "127.0.0.1" ||
      host.startsWith("127.");

  static HttpException _httpError(String operation, String path, int? status) =>
      HttpException("$operation failed (${status ?? "unknown"}) for '$path'.");
}

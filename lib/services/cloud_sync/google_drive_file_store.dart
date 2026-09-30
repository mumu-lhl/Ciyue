import "dart:io";

import "package:dio/dio.dart";

import "file_store.dart";

/// Google Drive v3 adapter using the least-privilege `drive.file` scope.
///
/// [rootFolderId] can be set to a folder explicitly granted to Ciyue by Google
/// Picker. Without a selected folder, the adapter starts at the user's Drive
/// root and can see files created by this application.
class GoogleDriveCloudFileStore implements CloudFileStore {
  static const folderMimeType = "application/vnd.google-apps.folder";

  final CloudAccessTokenProvider accessTokenProvider;
  final Dio _dio;
  final bool _ownsDio;
  final Uri apiBaseUri;
  final Uri uploadBaseUri;
  final String rootFolderId;
  int _temporaryNameCounter = 0;

  GoogleDriveCloudFileStore({
    required this.accessTokenProvider,
    Dio? dio,
    Uri? apiBaseUri,
    Uri? uploadBaseUri,
    this.rootFolderId = "root",
  }) : apiBaseUri = apiBaseUri ?? Uri.https("www.googleapis.com", "/drive/v3/"),
       uploadBaseUri =
           uploadBaseUri ??
           Uri.https("www.googleapis.com", "/upload/drive/v3/"),
       _dio = dio ?? Dio(),
       _ownsDio = dio == null;

  @override
  Future<List<CloudFileEntry>> listDirectory(String remotePath) async {
    final path = _cleanPath(remotePath);
    final folderId = await _resolveDirectory(path);
    if (folderId == null) return const [];
    final files = await _listChildren(folderId);
    final entries = files.map((file) {
      final name = file["name"] as String;
      final entryPath = path.isEmpty ? name : "$path/$name";
      final isDirectory = file["mimeType"] == folderMimeType;
      final rawSize = file["size"];
      return CloudFileEntry(
        name: name,
        path: entryPath,
        isDirectory: isDirectory,
        sizeBytes: rawSize == null ? null : int.tryParse(rawSize.toString()),
      );
    }).toList();
    _sortEntries(entries);
    return entries;
  }

  @override
  Future<void> ensureDirectory(String remotePath) async {
    final segments = _segments(remotePath);
    var parentId = rootFolderId;
    for (final segment in segments) {
      final existing = await _findChild(parentId, segment);
      if (existing != null) {
        if (existing["mimeType"] != folderMimeType) {
          throw FileSystemException(
            "A file blocks the cloud folder path",
            segment,
          );
        }
        parentId = _requiredId(existing);
        continue;
      }
      final response = await _request(
        "POST",
        apiBaseUri.resolve("files"),
        data: {
          "name": segment,
          "mimeType": folderMimeType,
          "parents": [parentId],
        },
      );
      final created = _decodeMap(response.data);
      parentId = _requiredId(created);
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
    final file = await _findFile(path);
    if (file == null) throw FileSystemException("Cloud file not found", path);
    final fileId = _requiredId(file);
    final uri = apiBaseUri
        .resolve("files/${Uri.encodeComponent(fileId)}")
        .replace(queryParameters: const {"alt": "media"});
    final temporary = File("${destination.path}.ciyue-download");
    await destination.parent.create(recursive: true);
    if (await temporary.exists()) await temporary.delete();
    try {
      final response = await _request(
        "GET",
        uri,
        responseType: ResponseType.stream,
        followRedirects: false,
      );
      if (response.statusCode != HttpStatus.ok &&
          (response.statusCode == null ||
              response.statusCode! < 300 ||
              response.statusCode! >= 400)) {
        throw _httpError("Drive download", path, response.statusCode);
      }
      final redirect = response.headers.value(HttpHeaders.locationHeader);
      if (redirect != null) {
        final downloadUri = uri.resolve(redirect);
        final download = await _dio.downloadUri(
          downloadUri,
          temporary.path,
          onReceiveProgress: onReceiveProgress,
          deleteOnError: true,
          options: Options(
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        if (download.statusCode != HttpStatus.ok) {
          throw _httpError("Drive download", path, download.statusCode);
        }
      } else {
        final body = response.data;
        if (body is! ResponseBody) {
          throw const FormatException("Drive returned an invalid file body.");
        }
        final sink = temporary.openWrite();
        var received = 0;
        try {
          await for (final chunk in body.stream) {
            sink.add(chunk);
            received += chunk.length;
            onReceiveProgress?.call(
              received,
              int.tryParse(
                    response.headers.value(HttpHeaders.contentLengthHeader) ??
                        "",
                  ) ??
                  -1,
            );
          }
        } finally {
          await sink.close();
        }
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
    final parentId = parentPath.isEmpty
        ? rootFolderId
        : await _resolveDirectory(parentPath);
    if (parentId == null) {
      throw FileSystemException("Cloud parent not found", parentPath);
    }

    final existing = await _findChild(parentId, name);
    if (existing != null && existing["mimeType"] == folderMimeType) {
      throw FileSystemException("A folder blocks the cloud file path", path);
    }
    var fileId = existing == null ? null : _requiredId(existing);
    var createdPlaceholder = false;
    if (fileId == null) {
      _temporaryNameCounter++;
      final stagedName =
          ".ciyue-upload-${DateTime.now().microsecondsSinceEpoch}-$_temporaryNameCounter";
      final metadataResponse = await _request(
        "POST",
        apiBaseUri.resolve("files"),
        data: {
          "name": stagedName,
          "mimeType": "application/octet-stream",
          "parents": [parentId],
        },
      );
      fileId = _requiredId(_decodeMap(metadataResponse.data));
      createdPlaceholder = true;
    }

    try {
      final uploadUri = uploadBaseUri
          .resolve("files/${Uri.encodeComponent(fileId)}")
          .replace(queryParameters: const {"uploadType": "media"});
      final response = await _request(
        "PATCH",
        uploadUri,
        data: source.openRead(),
        contentLength: await source.length(),
        onSendProgress: onSendProgress,
      );
      if (response.statusCode != HttpStatus.ok) {
        throw _httpError("Drive upload", path, response.statusCode);
      }
      if (createdPlaceholder) {
        await _request(
          "PATCH",
          apiBaseUri.resolve("files/${Uri.encodeComponent(fileId)}"),
          data: {"name": name},
        );
      }
    } catch (_) {
      if (createdPlaceholder) {
        try {
          await _request(
            "DELETE",
            apiBaseUri.resolve("files/${Uri.encodeComponent(fileId)}"),
          );
        } catch (_) {
          // Leave cleanup to the user if Drive is temporarily unavailable.
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    final path = _cleanPath(remotePath);
    if (path.isEmpty) throw ArgumentError.value(remotePath, "remotePath");
    final file = await _findFile(path);
    if (file == null) return;
    final response = await _request(
      "DELETE",
      apiBaseUri.resolve("files/${Uri.encodeComponent(_requiredId(file))}"),
    );
    if (response.statusCode != HttpStatus.noContent &&
        response.statusCode != HttpStatus.ok) {
      throw _httpError("Drive delete", path, response.statusCode);
    }
  }

  @override
  Future<void> close() async {
    if (_ownsDio) _dio.close(force: true);
  }

  Future<List<Map<String, dynamic>>> _listChildren(String parentId) async {
    final files = <Map<String, dynamic>>[];
    String? pageToken;
    do {
      final response = await _request(
        "GET",
        apiBaseUri.resolve("files"),
        queryParameters: {
          "q": "'${_escapeQuery(parentId)}' in parents and trashed = false",
          "pageSize": "1000",
          "fields": "nextPageToken,files(id,name,mimeType,size)",
          ...?pageToken == null ? null : {"pageToken": pageToken},
        },
      );
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw _httpError("Drive list", parentId, response.statusCode);
      }
      final body = _decodeMap(response.data);
      final values = body["files"];
      if (values is List) {
        for (final item in values) {
          if (item is Map) files.add(Map<String, dynamic>.from(item));
        }
      }
      pageToken = body["nextPageToken"] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return files;
  }

  Future<Map<String, dynamic>?> _findChild(String parentId, String name) async {
    final escapedName = _escapeQuery(name);
    final response = await _request(
      "GET",
      apiBaseUri.resolve("files"),
      queryParameters: {
        "q":
            "'${_escapeQuery(parentId)}' in parents and name = '$escapedName' and trashed = false",
        "pageSize": "100",
        "fields": "files(id,name,mimeType,size)",
      },
    );
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw _httpError("Drive list", name, response.statusCode);
    }
    final values = _decodeMap(response.data)["files"];
    if (values is! List) return null;
    final matches = values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
    if (matches.length > 1) {
      throw FileSystemException("More than one Drive item has this name", name);
    }
    return matches.firstOrNull;
  }

  Future<String?> _resolveDirectory(String path) async {
    var parentId = rootFolderId;
    for (final segment in _segments(path)) {
      final child = await _findChild(parentId, segment);
      if (child == null) return null;
      if (child["mimeType"] != folderMimeType) {
        throw FileSystemException(
          "A file blocks the cloud folder path",
          segment,
        );
      }
      parentId = _requiredId(child);
    }
    return parentId;
  }

  Future<Map<String, dynamic>?> _findFile(String path) async {
    final segments = _segments(path);
    if (segments.isEmpty) return null;
    final name = segments.removeLast();
    final parent = segments.isEmpty
        ? rootFolderId
        : await _resolveDirectory(segments.join("/"));
    if (parent == null) return null;
    final item = await _findChild(parent, name);
    if (item == null || item["mimeType"] == folderMimeType) return null;
    return item;
  }

  Future<Response<dynamic>> _request(
    String method,
    Uri uri, {
    Map<String, String>? queryParameters,
    Object? data,
    int? contentLength,
    ProgressCallback? onSendProgress,
    ResponseType? responseType,
    bool followRedirects = true,
  }) async {
    final token = await accessTokenProvider();
    return _dio.requestUri<dynamic>(
      queryParameters == null
          ? uri
          : uri.replace(queryParameters: queryParameters),
      data: data,
      onSendProgress: onSendProgress,
      options: Options(
        method: method,
        responseType: responseType,
        followRedirects: followRedirects,
        headers: {
          HttpHeaders.authorizationHeader: "Bearer $token",
          ...?contentLength == null
              ? null
              : {HttpHeaders.contentLengthHeader: contentLength},
          ...?data is Stream<List<int>>
              ? {HttpHeaders.contentTypeHeader: "application/octet-stream"}
              : null,
        },
        contentType: data is Map ? Headers.jsonContentType : null,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  static Map<String, dynamic> _decodeMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException("Drive returned an invalid JSON response.");
  }

  static String _requiredId(Map<String, dynamic> value) {
    final id = value["id"];
    if (id is! String || id.isEmpty) {
      throw const FormatException("Drive response did not include an item ID.");
    }
    return id;
  }

  static String _escapeQuery(String value) =>
      value.replaceAll(r"\", r"\\").replaceAll("'", r"\'");

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

  static void _sortEntries(List<CloudFileEntry> entries) {
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  static HttpException _httpError(String operation, String path, int? status) =>
      HttpException("$operation failed (${status ?? "unknown"}) for '$path'.");
}

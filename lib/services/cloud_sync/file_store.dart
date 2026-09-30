import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";
import "package:xml/xml.dart";

/// File operations required by Ciyue's versioned cloud sync format.
///
/// Paths are relative to the provider's configured root. Implementations must
/// stage downloads locally and replace the destination only after completion.
typedef CloudAccessTokenProvider = Future<String> Function();

abstract interface class CloudFileStore {
  Future<List<CloudFileEntry>> listDirectory(String remotePath);

  Future<void> ensureDirectory(String remotePath);

  Future<void> downloadFile(
    String remotePath,
    File destination, {
    ProgressCallback? onReceiveProgress,
  });

  Future<void> uploadFile(
    String remotePath,
    File source, {
    ProgressCallback? onSendProgress,
  });

  Future<void> deleteFile(String remotePath);

  Future<void> close();
}

class CloudFileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int? sizeBytes;

  const CloudFileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.sizeBytes,
  });
}

/// WebDAV implementation of [CloudFileStore].
///
/// Uploads use a temporary remote file followed by WebDAV MOVE, so an
/// interrupted transfer does not replace a previously valid snapshot. Large
/// files are streamed from disk rather than buffered in memory.
class WebDavCloudFileStore implements CloudFileStore {
  static const _propFindBody =
      "<?xml version=\"1.0\" encoding=\"utf-8\" ?>"
      "<d:propfind xmlns:d=\"DAV:\"><d:prop>"
      "<d:resourcetype/><d:getcontentlength/><d:getlastmodified/>"
      "</d:prop></d:propfind>";

  final Uri baseUri;
  final Dio _dio;
  final bool _ownsDio;
  int _temporaryFileCounter = 0;

  WebDavCloudFileStore({
    required Uri baseUri,
    String? username,
    String? password,
    Dio? dio,
  }) : baseUri = _normalizeBaseUri(baseUri),
       _dio = dio ?? Dio(),
       _ownsDio = dio == null {
    if (username != null || password != null) {
      if (this.baseUri.scheme != "https" &&
          !_isLoopbackHost(this.baseUri.host)) {
        throw ArgumentError("WebDAV credentials require HTTPS.");
      }
      if (username == null || password == null) {
        throw ArgumentError(
          "WebDAV username and password must be supplied together.",
        );
      }
      _dio.options.headers[HttpHeaders.authorizationHeader] =
          "Basic ${base64Encode(utf8.encode("$username:$password"))}";
    }
  }

  @override
  Future<List<CloudFileEntry>> listDirectory(String remotePath) async {
    final path = _cleanPath(remotePath);
    final response = await _request(
      "PROPFIND",
      _directoryPath(path),
      headers: const {
        "Depth": "1",
        "Content-Type": "application/xml; charset=utf-8",
      },
      data: _propFindBody,
      responseType: ResponseType.plain,
    );
    if (response.statusCode != 207 && response.statusCode != 200) {
      throw _statusException("PROPFIND", path, response.statusCode);
    }

    final document = XmlDocument.parse(response.data as String);
    final baseSegments = _nonEmptySegments(baseUri.pathSegments);
    final requestedSegments = _nonEmptySegments(path.split("/"));
    final entries = <CloudFileEntry>[];
    for (final responseElement in document.findAllElements(
      "response",
      namespaceUri: "DAV:",
    )) {
      final href = responseElement
          .findElements("href", namespaceUri: "DAV:")
          .firstOrNull
          ?.innerText;
      if (href == null) continue;

      final uri = Uri.parse(href);
      final segments = _nonEmptySegments(uri.pathSegments);
      if (!_startsWithSegments(segments, baseSegments) ||
          segments.length <= baseSegments.length) {
        continue;
      }
      final relativeSegments = segments.skip(baseSegments.length).toList();
      if (relativeSegments.length <= requestedSegments.length) continue;
      if (!_startsWithSegments(relativeSegments, requestedSegments)) continue;

      final name = relativeSegments.last;
      final relativePath = relativeSegments.join("/");
      final propstats = responseElement.findAllElements(
        "propstat",
        namespaceUri: "DAV:",
      );
      final isDirectory = propstats.any(
        (propstat) => propstat
            .findAllElements("collection", namespaceUri: "DAV:")
            .isNotEmpty,
      );
      final rawSize = propstats
          .expand(
            (propstat) => propstat.findAllElements(
              "getcontentlength",
              namespaceUri: "DAV:",
            ),
          )
          .firstOrNull
          ?.innerText;
      entries.add(
        CloudFileEntry(
          name: name,
          path: relativePath,
          isDirectory: isDirectory,
          sizeBytes: int.tryParse(rawSize ?? ""),
        ),
      );
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  @override
  Future<void> ensureDirectory(String remotePath) async {
    final segments = _nonEmptySegments(_cleanPath(remotePath).split("/"));
    var current = <String>[];
    for (final segment in segments) {
      current = [...current, segment];
      final path = current.join("/");
      final response = await _request("MKCOL", _directoryPath(path));
      if (_isSuccess(response.statusCode)) continue;
      if (response.statusCode == HttpStatus.methodNotAllowed ||
          response.statusCode == HttpStatus.preconditionFailed) {
        if (await _isCollection(path)) continue;
      }
      throw _statusException("MKCOL", path, response.statusCode);
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
    await destination.parent.create(recursive: true);
    final temporary = File("${destination.path}.ciyue-download");
    if (await temporary.exists()) {
      await temporary.delete();
    }
    try {
      final response = await _dio.downloadUri(
        _resolve(path),
        temporary.path,
        onReceiveProgress: onReceiveProgress,
        deleteOnError: true,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (!_isSuccess(response.statusCode)) {
        throw _statusException("GET", path, response.statusCode);
      }
      if (await destination.exists()) {
        await destination.delete();
      }
      await temporary.rename(destination.path);
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
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

    final parent = path.contains("/")
        ? path.substring(0, path.lastIndexOf("/"))
        : "";
    if (parent.isNotEmpty) await ensureDirectory(parent);

    _temporaryFileCounter++;
    final temporaryPath =
        "$parent${parent.isEmpty ? "" : "/"}.ciyue-upload-${DateTime.now().microsecondsSinceEpoch}-$_temporaryFileCounter";
    try {
      final response = await _dio.putUri<Object?>(
        _resolve(temporaryPath),
        data: source.openRead(),
        onSendProgress: onSendProgress,
        options: Options(
          headers: {HttpHeaders.contentLengthHeader: await source.length()},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (!_isSuccess(response.statusCode)) {
        throw _statusException("PUT", temporaryPath, response.statusCode);
      }

      final moveResponse = await _request(
        "MOVE",
        temporaryPath,
        headers: {"Destination": _resolve(path).toString(), "Overwrite": "T"},
      );
      if (!_isSuccess(moveResponse.statusCode)) {
        throw _statusException("MOVE", path, moveResponse.statusCode);
      }
    } catch (_) {
      try {
        await deleteFile(temporaryPath);
      } catch (_) {
        // Preserve the transfer error; a later cleanup can remove stale temps.
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    final path = _cleanPath(remotePath);
    if (path.isEmpty) throw ArgumentError.value(remotePath, "remotePath");
    final response = await _request(
      "DELETE",
      path,
      validateStatus: (status) => status != null && status < 500,
    );
    if (!_isSuccess(response.statusCode) &&
        response.statusCode != HttpStatus.notFound) {
      throw _statusException("DELETE", path, response.statusCode);
    }
  }

  @override
  Future<void> close() async {
    if (_ownsDio) _dio.close(force: true);
  }

  Future<bool> _isCollection(String path) async {
    final response = await _request(
      "PROPFIND",
      _directoryPath(path),
      headers: const {
        "Depth": "0",
        "Content-Type": "application/xml; charset=utf-8",
      },
      data: _propFindBody,
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null && status < 500,
    );
    if (response.statusCode != 207 && response.statusCode != 200) return false;
    final document = XmlDocument.parse(response.data as String);
    return document
        .findAllElements("collection", namespaceUri: "DAV:")
        .isNotEmpty;
  }

  Future<Response<T>> _request<T>(
    String method,
    String remotePath, {
    Map<String, Object?>? headers,
    Object? data,
    ResponseType? responseType,
    ValidateStatus? validateStatus,
  }) {
    return _dio.requestUri<T>(
      _resolve(remotePath),
      data: data,
      options: Options(
        method: method,
        headers: headers,
        responseType: responseType,
        validateStatus:
            validateStatus ?? (status) => status != null && status < 500,
      ),
    );
  }

  Uri _resolve(String remotePath) {
    final path = _cleanPath(remotePath);
    final encodedPath = path
        .split("/")
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join("/");
    return baseUri.resolve(encodedPath);
  }

  String _directoryPath(String path) => path.isEmpty ? "" : "$path/";

  String _cleanPath(String path) {
    final trimmed = path.trim().replaceAll("\\", "/");
    final segments = _nonEmptySegments(trimmed.split("/"));
    if (segments.any(
      (segment) =>
          segment == "." ||
          segment == ".." ||
          segment.contains("\u0000") ||
          segment.contains(":") ||
          segment.contains("%2f") ||
          segment.contains("%2F"),
    )) {
      throw ArgumentError.value(path, "remotePath", "Unsafe WebDAV path");
    }
    return segments.join("/");
  }

  static Uri _normalizeBaseUri(Uri uri) {
    if ((uri.scheme != "https" && uri.scheme != "http") ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw ArgumentError.value(
        uri,
        "baseUri",
        "Expected an HTTP(S) WebDAV URL without credentials or query",
      );
    }
    final path = uri.path.endsWith("/") ? uri.path : "${uri.path}/";
    return uri.replace(path: path);
  }

  static List<String> _nonEmptySegments(Iterable<String> segments) =>
      segments.where((segment) => segment.isNotEmpty).toList(growable: false);

  static bool _isLoopbackHost(String host) =>
      host == "localhost" ||
      host == "::1" ||
      InternetAddress.tryParse(host)?.isLoopback == true;

  static bool _startsWithSegments(List<String> path, List<String> prefix) {
    if (path.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (path[i] != prefix[i]) return false;
    }
    return true;
  }

  static bool _isSuccess(int? statusCode) =>
      statusCode != null && statusCode >= 200 && statusCode < 300;

  static HttpException _statusException(
    String method,
    String path,
    int? statusCode,
  ) => HttpException("WebDAV $method failed for '$path' (HTTP $statusCode).");
}

import "dart:convert";
import "dart:io";

import "package:ciyue/services/cloud_sync/one_drive_file_store.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late _FakeGraphServer server;
  late OneDriveCloudFileStore store;
  late Directory temporaryDirectory;

  setUp(() async {
    server = _FakeGraphServer();
    await server.start();
    store = OneDriveCloudFileStore(
      accessTokenProvider: () async => "graph-access-token",
      apiBaseUri: Uri.parse("http://127.0.0.1:${server.port}/v1.0/"),
    );
    temporaryDirectory = await Directory.systemTemp.createTemp(
      "ciyue-onedrive-test-",
    );
  });

  tearDown(() async {
    await store.close();
    await server.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    "creates directories and uploads files through a Graph session",
    () async {
      await store.ensureDirectory("Ciyue/sync");
      final source = File("${temporaryDirectory.path}/snapshot.json")
        ..writeAsStringSync('{"formatVersion":1}');

      await store.uploadFile("Ciyue/sync/snapshot.json", source);

      final entries = await store.listDirectory("Ciyue/sync");
      expect(entries, hasLength(1));
      expect(entries.single.name, "snapshot.json");
      expect(entries.single.sizeBytes, source.lengthSync());
      expect(
        server.items["Ciyue/sync/snapshot.json"]!.bytes,
        source.readAsBytesSync(),
      );
      expect(server.uploadAuthorizationHeaders, [null]);
      expect(
        server.uploadRanges.single,
        "bytes 0-${source.lengthSync() - 1}/${source.lengthSync()}",
      );
      expect(server.graphAuthorizationHeaders, isNotEmpty);
      expect(
        server.graphAuthorizationHeaders,
        everyElement("Bearer graph-access-token"),
      );
    },
  );

  test(
    "downloads via the provider URL and atomically replaces local file",
    () async {
      await store.ensureDirectory("Ciyue");
      server.addFile("Ciyue/data.bin", [1, 2, 3]);
      final destination = File("${temporaryDirectory.path}/data.bin")
        ..writeAsBytesSync([99]);

      await store.downloadFile("Ciyue/data.bin", destination);

      expect(await destination.readAsBytes(), [1, 2, 3]);
      expect(
        await File("${destination.path}.ciyue-download").exists(),
        isFalse,
      );
    },
  );

  test("rejects traversal without making a Graph request", () async {
    await expectLater(
      store.ensureDirectory("Ciyue/../private"),
      throwsArgumentError,
    );
    expect(server.graphAuthorizationHeaders, isEmpty);
  });
}

class _GraphItem {
  final String id;
  final String name;
  final String path;
  final bool isDirectory;
  List<int> bytes;

  _GraphItem({
    required this.id,
    required this.name,
    required this.path,
    required this.isDirectory,
    List<int> bytes = const [],
  }) : bytes = List.of(bytes);

  Map<String, Object?> toJson({String? downloadUrl}) => {
    "id": id,
    "name": name,
    "size": bytes.length,
    if (isDirectory)
      "folder": <String, Object?>{}
    else
      "file": <String, Object?>{},
    ...?downloadUrl == null
        ? null
        : {"@microsoft.graph.downloadUrl": downloadUrl},
  };
}

class _FakeGraphServer {
  HttpServer? _server;
  final Map<String, _GraphItem> items = {};
  final List<String?> graphAuthorizationHeaders = [];
  final List<String?> uploadAuthorizationHeaders = [];
  final List<String?> uploadRanges = [];
  int _nextId = 0;

  int get port => _server!.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> close() => _server!.close(force: true);

  void addFile(String path, List<int> bytes) {
    final name = path.split("/").last;
    items[path] = _GraphItem(
      id: "item-${++_nextId}",
      name: name,
      path: path,
      isDirectory: false,
      bytes: bytes,
    );
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (path.startsWith("/upload/")) {
      uploadAuthorizationHeaders.add(
        request.headers.value(HttpHeaders.authorizationHeader),
      );
      uploadRanges.add(request.headers.value(HttpHeaders.contentRangeHeader));
      await _receiveUpload(request);
    } else if (path.startsWith("/download/")) {
      await _download(request);
    } else {
      graphAuthorizationHeaders.add(
        request.headers.value(HttpHeaders.authorizationHeader),
      );
      await _graph(request);
    }
    await request.response.close();
  }

  Future<void> _graph(HttpRequest request) async {
    final path = request.uri.path;
    if (request.method == "GET" && path.endsWith("/root/children")) {
      _writeJson(request, {"value": _children("")});
      return;
    }

    final childrenMatch = RegExp(r"/root:/(.*):/children$").firstMatch(path);
    if (request.method == "GET" && childrenMatch != null) {
      _writeJson(request, {"value": _children(childrenMatch.group(1)!)});
      return;
    }
    if (request.method == "POST" && path.endsWith("/root/children")) {
      final body = await _readJson(request);
      final name = body["name"] as String;
      final itemPath = name;
      final item = _GraphItem(
        id: "item-${++_nextId}",
        name: name,
        path: itemPath,
        isDirectory: true,
      );
      items[itemPath] = item;
      request.response.statusCode = HttpStatus.created;
      _writeJson(request, item.toJson());
      return;
    }
    final createChildMatch = RegExp(r"/root:/(.*):/children$").firstMatch(path);
    if (request.method == "POST" && createChildMatch != null) {
      final parent = createChildMatch.group(1)!;
      final body = await _readJson(request);
      final name = body["name"] as String;
      final itemPath = "$parent/$name";
      final item = _GraphItem(
        id: "item-${++_nextId}",
        name: name,
        path: itemPath,
        isDirectory: true,
      );
      items[itemPath] = item;
      request.response.statusCode = HttpStatus.created;
      _writeJson(request, item.toJson());
      return;
    }

    final uploadByPath = RegExp(r"/root:/(.*):/createUploadSession$")
        .firstMatch(path);
    final uploadById = RegExp(r"/items/([^/]+)/createUploadSession$")
        .firstMatch(path);
    if (request.method == "POST" &&
        (uploadByPath != null || uploadById != null)) {
      final body = await _readJson(request);
      final itemProperties = body["item"] as Map<String, dynamic>;
      final targetPath =
          uploadByPath?.group(1) ??
          items.values
              .singleWhere((item) => item.id == uploadById!.group(1))
              .path;
      final name = targetPath.split("/").last;
      final item = items.putIfAbsent(
        targetPath,
        () => _GraphItem(
          id: "item-${++_nextId}",
          name: name,
          path: targetPath,
          isDirectory: false,
        ),
      );
      expect(itemProperties["name"], name);
      request.response.statusCode = HttpStatus.ok;
      _writeJson(request, {
        "uploadUrl": "http://127.0.0.1:$port/upload/${item.id}",
      });
      return;
    }

    final itemMatch = RegExp(r"/items/([^/]+)$").firstMatch(path);
    if (request.method == "GET" && itemMatch != null) {
      final item = items.values.cast<_GraphItem?>().firstWhere(
        (item) => item?.id == itemMatch.group(1),
        orElse: () => null,
      );
      if (item == null) {
        request.response.statusCode = HttpStatus.notFound;
        return;
      }
      _writeJson(
        request,
        item.toJson(downloadUrl: "http://127.0.0.1:$port/download/${item.id}"),
      );
      return;
    }
    final itemPathMatch = RegExp(r"/root:/(.*)$").firstMatch(path);
    if (request.method == "GET" && itemPathMatch != null) {
      final itemPath = itemPathMatch.group(1)!;
      final item = items[itemPath];
      if (item == null) {
        request.response.statusCode = HttpStatus.notFound;
        return;
      }
      _writeJson(request, item.toJson());
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
  }

  List<Map<String, Object?>> _children(String parentPath) => items.values
      .where((item) {
        final parent = item.path.contains("/")
            ? item.path.substring(0, item.path.lastIndexOf("/"))
            : "";
        return parent == parentPath;
      })
      .map((item) => item.toJson())
      .toList();

  Future<void> _receiveUpload(HttpRequest request) async {
    final id = request.uri.pathSegments.last;
    final item = items.values.cast<_GraphItem?>().firstWhere(
      (item) => item?.id == id,
      orElse: () => null,
    );
    if (item == null) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }
    item.bytes = await request.fold<List<int>>(
      [],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    request.response.statusCode = HttpStatus.created;
    _writeJson(request, item.toJson());
  }

  Future<void> _download(HttpRequest request) async {
    final id = request.uri.pathSegments.last;
    final item = items.values.cast<_GraphItem?>().firstWhere(
      (item) => item?.id == id,
      orElse: () => null,
    );
    if (item == null) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }
    request.response.headers.contentType = ContentType.binary;
    request.response.add(item.bytes);
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final chunks = await request.fold<List<int>>(
      [],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    return jsonDecode(utf8.decode(chunks)) as Map<String, dynamic>;
  }

  void _writeJson(HttpRequest request, Object value) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(value));
  }
}

import "dart:convert";
import "dart:io";

import "package:ciyue/services/cloud_sync/google_drive_file_store.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late _FakeDriveServer server;
  late GoogleDriveCloudFileStore store;
  late Directory temporaryDirectory;

  setUp(() async {
    server = _FakeDriveServer();
    await server.start();
    store = GoogleDriveCloudFileStore(
      accessTokenProvider: () async => "test-access-token",
      apiBaseUri: Uri.parse("http://127.0.0.1:${server.port}/drive/v3/"),
      uploadBaseUri: Uri.parse(
        "http://127.0.0.1:${server.port}/upload/drive/v3/",
      ),
    );
    temporaryDirectory = await Directory.systemTemp.createTemp(
      "ciyue-drive-test-",
    );
  });

  tearDown(() async {
    await store.close();
    await server.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test("creates folders, streams files, and lists Drive children", () async {
    await store.ensureDirectory("Ciyue/sync");
    final source = File("${temporaryDirectory.path}/snapshot.json")
      ..writeAsStringSync('{"formatVersion":1}');

    await store.uploadFile("Ciyue/sync/snapshot.json", source);

    final entries = await store.listDirectory("Ciyue/sync");
    expect(entries, hasLength(1));
    expect(entries.single.name, "snapshot.json");
    expect(entries.single.sizeBytes, source.lengthSync());
    expect(server.authorizationHeaders, isNotEmpty);
    expect(
      server.files.values
          .singleWhere((file) => file.name == "snapshot.json")
          .bytes,
      '{"formatVersion":1}'.codeUnits,
    );
    expect(
      server.files.values.where(
        (file) => file.name.startsWith(".ciyue-upload-"),
      ),
      isEmpty,
    );
  });

  test(
    "downloads to a temporary file before replacing the destination",
    () async {
      await store.ensureDirectory("Ciyue");
      final remote = File("${temporaryDirectory.path}/remote.bin")
        ..writeAsBytesSync([1, 2, 3, 4]);
      await store.uploadFile("Ciyue/data.bin", remote);
      final destination = File("${temporaryDirectory.path}/destination.bin")
        ..writeAsBytesSync([99]);

      await store.downloadFile("Ciyue/data.bin", destination);

      expect(await destination.readAsBytes(), [1, 2, 3, 4]);
      expect(
        await File("${destination.path}.ciyue-download").exists(),
        isFalse,
      );
    },
  );

  test("rejects traversal without making a request", () async {
    await expectLater(
      store.ensureDirectory("Ciyue/../private"),
      throwsArgumentError,
    );
    expect(server.requestCount, 0);
  });
}

class _DriveFile {
  final String id;
  String name;
  final String parentId;
  final String mimeType;
  List<int> bytes;

  _DriveFile({
    required this.id,
    required this.name,
    required this.parentId,
    required this.mimeType,
    List<int> bytes = const [],
  }) : bytes = List.of(bytes);

  Map<String, Object?> toJson() => {
    "id": id,
    "name": name,
    "mimeType": mimeType,
    "size": bytes.length.toString(),
  };
}

class _FakeDriveServer {
  HttpServer? _server;
  final Map<String, _DriveFile> files = {};
  final List<String?> authorizationHeaders = [];
  int requestCount = 0;
  int _nextId = 0;

  int get port => _server!.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> close() => _server!.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    requestCount++;
    authorizationHeaders.add(
      request.headers.value(HttpHeaders.authorizationHeader),
    );
    final path = request.uri.path;
    if (path.endsWith("/files") && request.method == "GET") {
      await _list(request);
    } else if (path.endsWith("/files") && request.method == "POST") {
      await _create(request);
    } else if (path.startsWith("/upload/drive/v3/files/") &&
        request.method == "PATCH") {
      await _upload(request);
    } else if (path.startsWith("/drive/v3/files/")) {
      await _item(request);
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  }

  Future<void> _list(HttpRequest request) async {
    final query = request.uri.queryParameters["q"] ?? "";
    final parentMatch = RegExp(r"'([^']+)' in parents").firstMatch(query);
    final parentId = parentMatch?.group(1);
    final nameMatch = RegExp(r"name = '((?:\\'|[^'])*)'").firstMatch(query);
    final wantedName = nameMatch?.group(1)?.replaceAll(r"\'", "'");
    final matches = files.values
        .where((file) {
          return file.parentId == parentId &&
              (wantedName == null || file.name == wantedName);
        })
        .map((file) => file.toJson())
        .toList();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({"files": matches}));
  }

  Future<void> _create(HttpRequest request) async {
    final body = jsonDecode(
      await utf8.decoder.bind(request).join(),
    ) as Map<String, dynamic>;
    final parents = body["parents"] as List<dynamic>;
    final file = _DriveFile(
      id: "drive-${++_nextId}",
      name: body["name"] as String,
      parentId: parents.single as String,
      mimeType: body["mimeType"] as String,
    );
    files[file.id] = file;
    request.response.statusCode = HttpStatus.created;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(file.toJson()));
  }

  Future<void> _upload(HttpRequest request) async {
    final id = request.uri.pathSegments.last;
    final item = files[id];
    if (item == null) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }
    item.bytes = await request.fold<List<int>>(
      [],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(item.toJson()));
  }

  Future<void> _item(HttpRequest request) async {
    final id = request.uri.pathSegments.last;
    final item = files[id];
    if (item == null) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }
    if (request.method == "GET" &&
        request.uri.queryParameters["alt"] == "media") {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.binary;
      request.response.add(item.bytes);
    } else if (request.method == "PATCH") {
      final body = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      if (body["name"] is String) item.name = body["name"] as String;
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(item.toJson()));
    } else if (request.method == "DELETE") {
      files.remove(id);
      request.response.statusCode = HttpStatus.noContent;
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
    }
  }
}

import "dart:io";

import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late _FakeWebDavServer server;
  late WebDavCloudFileStore store;
  late Directory tempDirectory;

  setUp(() async {
    server = _FakeWebDavServer();
    await server.start();
    store = WebDavCloudFileStore(
      baseUri: Uri.parse("http://127.0.0.1:${server.port}/remote.php/dav/"),
      dio: Dio(),
    );
    tempDirectory = await Directory.systemTemp.createTemp("ciyue-webdav-test");
  });

  tearDown(() async {
    await store.close();
    await server.close();
    await tempDirectory.delete(recursive: true);
  });

  test("creates each directory level and accepts existing folders", () async {
    await store.ensureDirectory("Ciyue/dictionaries/mdx");
    await store.ensureDirectory("Ciyue/dictionaries/mdx");

    expect(
      server.directories,
      containsAll([
        "/remote.php/dav/Ciyue/",
        "/remote.php/dav/Ciyue/dictionaries/",
        "/remote.php/dav/Ciyue/dictionaries/mdx/",
      ]),
    );
  });

  test(
    "uploads through a temporary remote file then downloads atomically",
    () async {
      await store.ensureDirectory("Ciyue/wordbook");
      final source = File("${tempDirectory.path}/snapshot.json");
      await source.writeAsString('{"formatVersion":1,"records":[]}');

      await store.uploadFile("Ciyue/wordbook/snapshot.json", source);

      final destination = File("${tempDirectory.path}/restored.json");
      await store.downloadFile("Ciyue/wordbook/snapshot.json", destination);
      expect(
        await destination.readAsString(),
        '{"formatVersion":1,"records":[]}',
      );
      expect(
        server.files.keys,
        contains("/remote.php/dav/Ciyue/wordbook/snapshot.json"),
      );
      expect(
        server.files.keys.where((path) => path.contains(".ciyue-upload-")),
        isEmpty,
      );
    },
  );

  test("lists immediate files and directories with sizes", () async {
    await store.ensureDirectory("Ciyue/dictionaries");
    final first = File("${tempDirectory.path}/one.mdx")
      ..writeAsStringSync("abc");
    final second = File("${tempDirectory.path}/two.mdd")
      ..writeAsStringSync("12345");
    await store.uploadFile("Ciyue/dictionaries/one.mdx", first);
    await store.uploadFile("Ciyue/dictionaries/two.mdd", second);
    await store.ensureDirectory("Ciyue/dictionaries/images");

    final entries = await store.listDirectory("Ciyue/dictionaries");

    expect(entries.map((entry) => entry.name).toSet(), {
      "one.mdx",
      "two.mdd",
      "images",
    });
    expect(
      entries.singleWhere((entry) => entry.name == "one.mdx").sizeBytes,
      3,
    );
    expect(
      entries.singleWhere((entry) => entry.name == "images").isDirectory,
      isTrue,
    );
  });

  test("requires HTTPS when credentials would leave the device", () {
    expect(
      () => WebDavCloudFileStore(
        baseUri: Uri.parse("http://webdav.example.com/dav/"),
        username: "user",
        password: "secret",
      ),
      throwsArgumentError,
    );
  });

  test("rejects path traversal before making a request", () async {
    await expectLater(
      store.ensureDirectory("Ciyue/../private"),
      throwsArgumentError,
    );
    expect(server.requestCount, 0);
  });
}

class _FakeWebDavServer {
  HttpServer? _server;
  final Set<String> directories = {"/remote.php/dav/"};
  final Map<String, List<int>> files = {};
  int requestCount = 0;

  int get port => _server!.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> close() => _server!.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    requestCount++;
    final path = request.uri.path;
    switch (request.method) {
      case "MKCOL":
        if (directories.contains(_asDirectory(path))) {
          request.response.statusCode = HttpStatus.methodNotAllowed;
        } else if (!directories.contains(_parentDirectory(path))) {
          request.response.statusCode = HttpStatus.conflict;
        } else {
          directories.add(_asDirectory(path));
          request.response.statusCode = HttpStatus.created;
        }
      case "PROPFIND":
        await _propfind(request, path);
      case "PUT":
        files[path] = await request.fold<List<int>>(
          <int>[],
          (all, chunk) => all..addAll(chunk),
        );
        request.response.statusCode = HttpStatus.created;
      case "GET":
        final content = files[path];
        if (content == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.headers.contentType = ContentType.binary;
          request.response.add(content);
        }
      case "MOVE":
        final destination = Uri.parse(request.headers.value("destination")!)
            .path;
        final content = files.remove(path);
        if (content == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          files[destination] = content;
          request.response.statusCode = HttpStatus.created;
        }
      case "DELETE":
        files.remove(path);
        directories.remove(_asDirectory(path));
        request.response.statusCode = HttpStatus.noContent;
      default:
        request.response.statusCode = HttpStatus.methodNotAllowed;
    }
    await request.response.close();
  }

  Future<void> _propfind(HttpRequest request, String path) async {
    final currentPath = request.headers.value("depth") == "0"
        ? _asDirectory(path)
        : path;
    if (!directories.contains(_asDirectory(path)) && !files.containsKey(path)) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }
    final children = <String>{currentPath};
    if (request.headers.value("depth") != "0") {
      children.addAll(
        directories.where(
          (directory) => _parentDirectory(directory) == _asDirectory(path),
        ),
      );
      children.addAll(
        files.keys.where(
          (file) => _parentDirectory(file) == _asDirectory(path),
        ),
      );
    }
    final responses = children.map((child) {
      final collection = directories.contains(_asDirectory(child));
      final length = files[child]?.length ?? 0;
      return """
        <d:response><d:href>$child</d:href><d:propstat><d:prop>
        <d:resourcetype>${collection ? "<d:collection/>" : ""}</d:resourcetype>
        <d:getcontentlength>$length</d:getcontentlength>
        </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
      """;
    }).join();
    request.response.statusCode = 207;
    request.response.headers.contentType = ContentType("application", "xml");
    request.response.write(
      "<d:multistatus xmlns:d=\"DAV:\">$responses</d:multistatus>",
    );
  }

  String _asDirectory(String path) => path.endsWith("/") ? path : "$path/";

  String _parentDirectory(String path) {
    final withoutTrailingSlash = path.endsWith("/")
        ? path.substring(0, path.length - 1)
        : path;
    final parent = withoutTrailingSlash.substring(
      0,
      withoutTrailingSlash.lastIndexOf("/") + 1,
    );
    return parent.isEmpty ? "/" : parent;
  }
}

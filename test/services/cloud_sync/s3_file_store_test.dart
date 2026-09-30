import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/services/cloud_sync/s3_file_store.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  late Map<String, Uint8List> objects;
  late List<http.BaseRequest> requests;
  late S3CloudFileStore store;
  late Directory tempDirectory;

  setUp(() async {
    objects = {};
    requests = [];
    final client = MockClient.streaming((request, bodyStream) async {
      requests.add(request);
      final path = request.url.pathSegments.skip(1).join("/");
      if (request.method == "GET" &&
          request.url.queryParameters["list-type"] == "2") {
        final prefix = request.url.queryParameters["prefix"] ?? "";
        final delimiter = request.url.queryParameters["delimiter"];
        final contents = <String>[];
        final commonPrefixes = <String>{};
        for (final key in objects.keys.where((key) => key.startsWith(prefix))) {
          final rest = key.substring(prefix.length);
          if (delimiter != null && rest.contains(delimiter)) {
            final boundary = rest.indexOf(delimiter) + delimiter.length;
            commonPrefixes.add(prefix + rest.substring(0, boundary));
          } else {
            contents.add(key);
          }
        }
        final contentXml = contents
            .map(
              (key) =>
                  "<Contents><Key>${_escape(key)}</Key><ETag>\"etag\"</ETag>"
                  "<Size>${objects[key]!.length}</Size><StorageClass>STANDARD</StorageClass>"
                  "<LastModified>2026-01-01T00:00:00Z</LastModified></Contents>",
            )
            .join();
        final prefixXml = commonPrefixes
            .map(
              (value) =>
                  "<CommonPrefixes><Prefix>${_escape(value)}</Prefix></CommonPrefixes>",
            )
            .join();
        final xml =
            """
          <ListBucketResult>
            <Name>test-bucket</Name><Prefix>${_escape(prefix)}</Prefix>
            <MaxKeys>1000</MaxKeys><IsTruncated>false</IsTruncated>
            <KeyCount>${contents.length + commonPrefixes.length}</KeyCount>
            $contentXml$prefixXml
          </ListBucketResult>
          """;
        return http.StreamedResponse(
          Stream.value(utf8.encode(xml)),
          200,
          request: request,
        );
      }

      if (request.method == "PUT") {
        final data = await bodyStream.toBytes();
        final copySource = request.headers["x-amz-copy-source"];
        if (copySource != null) {
          final sourceKey = copySource
              .split("/")
              .skip(1)
              .map(Uri.decodeComponent)
              .join("/");
          objects[path] = objects[sourceKey]!;
          return http.StreamedResponse(
            Stream.value(
              utf8.encode("""
              <CopyObjectResult><ETag>"etag"</ETag>
              <LastModified>2026-01-01T00:00:00Z</LastModified></CopyObjectResult>
              """),
            ),
            200,
            headers: {"etag": "\"etag\""},
            request: request,
          );
        }
        objects[path] = Uint8List.fromList(data);
        return http.StreamedResponse(
          const Stream.empty(),
          200,
          headers: {"etag": "\"etag\""},
          request: request,
        );
      }

      if (request.method == "GET") {
        final data = objects[path];
        if (data == null) {
          return http.StreamedResponse(
            Stream.value(utf8.encode("missing")),
            404,
            request: request,
          );
        }
        return http.StreamedResponse(
          Stream.value(data),
          200,
          contentLength: data.length,
          request: request,
        );
      }

      if (request.method == "DELETE") {
        objects.remove(path);
        return http.StreamedResponse(
          const Stream.empty(),
          204,
          request: request,
        );
      }
      return http.StreamedResponse(const Stream.empty(), 400, request: request);
    });

    store = S3CloudFileStore(
      endpoint: Uri.parse("https://s3.example.test"),
      bucket: "test-bucket",
      region: "us-east-1",
      accessKeyId: "access-test",
      secretAccessKey: "secret-test",
      httpClient: client,
    );
    tempDirectory = await Directory.systemTemp.createTemp("ciyue-s3-store-");
  });

  tearDown(() async {
    await store.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    "lists marker directories, atomically uploads, downloads, and deletes",
    () async {
      await store.ensureDirectory("Ciyue/sync");
      expect(objects.keys, containsAll(["Ciyue/", "Ciyue/sync/"]));
      final rootEntries = await store.listDirectory("");
      expect(rootEntries.single.name, "Ciyue");
      expect(rootEntries.single.isDirectory, isTrue);
      final rootListRequest = requests.firstWhere(
        (request) => request.url.queryParameters["list-type"] == "2",
      );
      expect(rootListRequest.url.queryParameters["prefix"], "Ciyue/");
      final syncEntries = await store.listDirectory("Ciyue");
      expect(syncEntries.single.path, "Ciyue/sync");
      expect(syncEntries.single.isDirectory, isTrue);

      final source = File("${tempDirectory.path}/snapshot.json");
      await source.writeAsString('{"snapshot":true}');
      await store.uploadFile("Ciyue/sync/snapshot.json", source);
      expect(
        utf8.decode(objects["Ciyue/sync/snapshot.json"]!),
        '{"snapshot":true}',
      );
      expect(
        objects.keys.where((key) => key.startsWith(".ciyue-tmp-")),
        isEmpty,
      );

      final fileEntries = await store.listDirectory("Ciyue/sync");
      expect(fileEntries.single.name, "snapshot.json");
      expect(fileEntries.single.sizeBytes, source.lengthSync());

      final destination = File("${tempDirectory.path}/downloaded.json");
      await store.downloadFile("Ciyue/sync/snapshot.json", destination);
      expect(await destination.readAsString(), '{"snapshot":true}');

      await store.deleteFile("Ciyue/sync/snapshot.json");
      expect(objects, contains("Ciyue/sync/"));
      expect(
        requests.every(
          (request) =>
              request.headers["authorization"]?.startsWith(
                "AWS4-HMAC-SHA256 ",
              ) ==
              true,
        ),
        isTrue,
      );
    },
  );

  test("requires TLS except for loopback S3 endpoints", () {
    expect(
      () => S3CloudFileStore(
        endpoint: Uri.parse("http://storage.example.test"),
        bucket: "bucket",
        region: "us-east-1",
        accessKeyId: "key",
        secretAccessKey: "secret",
      ),
      throwsArgumentError,
    );
    expect(
      () => S3CloudFileStore(
        endpoint: Uri.parse("https://s3.example.test/prefix"),
        bucket: "bucket",
        region: "us-east-1",
        accessKeyId: "key",
        secretAccessKey: "secret",
        usePathStyle: false,
      ),
      throwsArgumentError,
    );
    final local = S3CloudFileStore(
      endpoint: Uri.parse("http://127.0.0.1:9000"),
      bucket: "bucket",
      region: "us-east-1",
      accessKeyId: "key",
      secretAccessKey: "secret",
    );
    addTearDown(local.close);
  });
}

String _escape(String value) => value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");

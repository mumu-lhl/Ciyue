import "dart:io";
import "dart:typed_data";

import "package:archive/archive.dart";
import "package:ciyue/repositories/stardict.dart";
import "package:flutter_test/flutter_test.dart";

List<int> _zipBytes(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return ZipEncoder().encode(archive);
}

void main() {
  late Directory dir;
  late Stardict dict;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp("stardict-zip-test");
    dict = Stardict(path: "${dir.path}/fixture");
  });

  tearDown(() async {
    await dict.close();
    await dir.delete(recursive: true);
  });

  test("reads a loose res/ file by either spelling", () async {
    final res = Directory("${dir.path}/res")..createSync();
    await File("${res.path}/pic.png").writeAsBytes([1, 2, 3]);

    expect(await dict.readResourceFile("res/pic.png"), [1, 2, 3]);
    expect(await dict.readResourceFile("pic.png"), [1, 2, 3]);
  });

  test("falls back to res.zip when the directory has no such file", () async {
    await File("${dir.path}/res.zip").writeAsBytes(
      _zipBytes({
        "pic.png": [4, 5],
      }),
    );

    expect(await dict.readResourceFile("res/pic.png"), [4, 5]);
    expect(await dict.readResourceFile("pic.png"), [4, 5]);
  });

  test("finds entries stored under a res/ prefix inside the zip", () async {
    await File("${dir.path}/res.zip").writeAsBytes(
      _zipBytes({
        "res/pic.png": [6],
      }),
    );

    expect(await dict.readResourceFile("res/pic.png"), [6]);
  });

  test("a loose file wins over the archive", () async {
    final res = Directory("${dir.path}/res")..createSync();
    await File("${res.path}/pic.png").writeAsBytes([1]);
    await File("${dir.path}/res.zip").writeAsBytes(
      _zipBytes({
        "pic.png": [2],
      }),
    );

    expect(await dict.readResourceFile("res/pic.png"), [1]);
  });

  test("tries <name>.res.zip before res/res.zip", () async {
    await File("${dir.path}/fixture.res.zip").writeAsBytes(
      _zipBytes({
        "pic.png": [7],
      }),
    );
    await File("${dir.path}/res.zip").writeAsBytes(
      _zipBytes({
        "other.png": [8],
      }),
    );
    final res = Directory("${dir.path}/res")..createSync();
    await File("${res.path}/res.zip").writeAsBytes(
      _zipBytes({
        "pic.png": [9],
      }),
    );

    expect(await dict.readResourceFile("pic.png"), [7]);
  });

  test(
    "falls through to res/res.zip when the first two have nothing",
    () async {
      await File("${dir.path}/res.zip").writeAsBytes(
        _zipBytes({
          "other.png": [8],
        }),
      );
      final res = Directory("${dir.path}/res")..createSync();
      await File("${res.path}/res.zip").writeAsBytes(
        _zipBytes({
          "pic.png": [9],
        }),
      );

      expect(await dict.readResourceFile("pic.png"), [9]);
    },
  );

  test("res.zip wins over <name>.res.zip", () async {
    await File("${dir.path}/res.zip").writeAsBytes(
      _zipBytes({
        "pic.png": [1],
      }),
    );
    await File("${dir.path}/fixture.res.zip").writeAsBytes(
      _zipBytes({
        "pic.png": [2],
      }),
    );

    expect(await dict.readResourceFile("pic.png"), [1]);
  });

  test("refuses paths escaping the dictionary directory", () async {
    await File("${dir.path}/res.zip").writeAsBytes(
      _zipBytes({
        "../secret.txt": [2],
        "secret.txt": [3],
      }),
    );

    expect(await dict.readResourceFile("res/../secret.txt"), isNull);
    expect(await dict.readResourceFile("../secret.txt"), isNull);
    // The legitimately named entry in the same archive stays readable.
    expect(await dict.readResourceFile("secret.txt"), [3]);
  });

  test("returns null when nothing holds the resource", () async {
    expect(await dict.readResourceFile("res/missing.png"), isNull);
    expect(await dict.readResourceFile("missing.png"), isNull);
    expect(await dict.readResourceFile("res/"), isNull);
  });

  test("readResourceFile returns raw bytes usable as an image", () async {
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
    await File("${dir.path}/res.zip").writeAsBytes(_zipBytes({"pic.png": png}));

    expect(await dict.readResourceFile("pic.png"), png);
  });
}

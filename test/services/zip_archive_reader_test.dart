import "dart:io";
import "dart:typed_data";

import "package:archive/archive.dart";
import "package:ciyue/services/zip_archive_reader.dart";
import "package:flutter_test/flutter_test.dart";

List<int> _zipBytes(
  Map<String, List<int>> entries, {
  Set<String> stored = const {},
}) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final file = ArchiveFile(entry.key, entry.value.length, entry.value);
    if (stored.contains(entry.key)) {
      file.compression = CompressionType.none;
    }
    archive.addFile(file);
  }
  return ZipEncoder().encode(archive);
}

void main() {
  late Directory dir;
  final readers = <ZipArchiveReader>[];

  ZipArchiveReader openReader(File file) {
    final reader = ZipArchiveReader(file);
    readers.add(reader);
    return reader;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp("ciyue-zip-test");
  });

  tearDown(() async {
    for (final reader in readers) {
      reader.close();
    }
    readers.clear();
    await dir.delete(recursive: true);
  });

  test("reads deflated and stored entries on demand", () async {
    final file = File("${dir.path}/pack.zip")
      ..writeAsBytesSync(
        _zipBytes(
          {
            "deflated.txt": [1, 2, 3, 4, 5],
            "stored.txt": [6, 7, 8],
          },
          stored: {"stored.txt"},
        ),
      );
    final reader = openReader(file);

    expect(await reader.readEntry("deflated.txt"), [1, 2, 3, 4, 5]);
    expect(await reader.readEntry("stored.txt"), [6, 7, 8]);
  });

  test("reads nested entries by exact name", () async {
    final file = File("${dir.path}/pack.zip")
      ..writeAsBytesSync(
        _zipBytes({
          "images/pic.png": [9, 9, 9],
          "res/pic.png": [8, 8, 8],
        }),
      );
    final reader = openReader(file);

    expect(await reader.readEntry("images/pic.png"), [9, 9, 9]);
    expect(await reader.readEntry("res/pic.png"), [8, 8, 8]);
  });

  test("returns null for a missing entry, file, or non-zip", () async {
    final file = File("${dir.path}/pack.zip")
      ..writeAsBytesSync(
        _zipBytes({
          "a.txt": [1],
        }),
      );
    final reader = openReader(file);

    expect(await reader.readEntry("missing.txt"), isNull);
    expect(
      await openReader(File("${dir.path}/nope.zip")).readEntry("a.txt"),
      isNull,
    );
    final garbage = File("${dir.path}/garbage.zip")
      ..writeAsStringSync("this is not a zip archive at all");
    expect(await openReader(garbage).readEntry("a.txt"), isNull);
  });

  test("never exposes entries escaping the archive root", () async {
    final file = File("${dir.path}/pack.zip")
      ..writeAsBytesSync(
        _zipBytes({
          "../evil.txt": [1],
          "good.txt": [2],
        }),
      );
    final reader = openReader(file);

    expect(await reader.readEntry("../evil.txt"), isNull);
    expect(await reader.readEntry("evil.txt"), isNull);
    expect(await reader.readEntry("good.txt"), [2]);
  });

  test("matches names case-insensitively as a fallback", () async {
    final file = File("${dir.path}/pack.zip")
      ..writeAsBytesSync(
        _zipBytes({
          "Pic.PNG": [3, 3],
        }),
      );
    final reader = openReader(file);

    expect(await reader.readEntry("Pic.PNG"), [3, 3]);
    expect(await reader.readEntry("pic.png"), [3, 3]);
  });

  test("concurrent reads return the right bytes", () async {
    final entries = {
      for (var i = 0; i < 8; i++) "file$i.bin": [i],
    };
    final file = File("${dir.path}/pack.zip")
      ..writeAsBytesSync(_zipBytes(entries));
    final reader = openReader(file);

    final results = await Future.wait(entries.keys.map(reader.readEntry));
    for (var i = 0; i < 8; i++) {
      expect(results[i], [i]);
    }
  });

  test("containsEntry answers without inflating", () async {
    final file = File("${dir.path}/pack.zip")
      ..writeAsBytesSync(
        _zipBytes({
          "a.txt": [1],
        }),
      );
    final reader = openReader(file);

    expect(await reader.containsEntry("a.txt"), isTrue);
    expect(await reader.containsEntry("b.txt"), isFalse);
    expect(await reader.containsEntry("../a.txt"), isFalse);
  });

  test("reads stop after close", () async {
    final file = File("${dir.path}/pack.zip")
      ..writeAsBytesSync(
        _zipBytes({
          "a.txt": [1],
        }),
      );
    final reader = openReader(file);
    expect(await reader.readEntry("a.txt"), [1]);

    reader.close();
    expect(await reader.readEntry("a.txt"), isNull);
  });

  test("reads a large entry without loading the whole archive", () async {
    final big = Uint8List(1024 * 1024);
    for (var i = 0; i < big.length; i++) {
      big[i] = i % 251;
    }
    final file = File("${dir.path}/pack.zip")
      ..writeAsBytesSync(
        _zipBytes({
          "small.txt": [1],
          "big.bin": big,
        }),
      );
    final reader = openReader(file);

    final data = await reader.readEntry("big.bin");
    expect(data, big);
  });
}

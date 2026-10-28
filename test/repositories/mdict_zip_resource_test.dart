import "dart:io";

import "package:archive/archive.dart";
import "package:ciyue/repositories/dictionary.dart";
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
  late Mdict dict;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp("mdict-zip-test");
    dict = Mdict(path: "${dir.path}/oxford");
  });

  tearDown(() async {
    await dict.close();
    await dir.delete(recursive: true);
  });

  test("reads audio from <path>.zip", () async {
    await File("${dir.path}/oxford.zip").writeAsBytes(
      _zipBytes({
        "hello.mp3": [1, 2, 3],
      }),
    );

    expect(await dict.readZipResource("hello.mp3"), [1, 2, 3]);
    expect(await dict.containsZipResource("hello.mp3"), isTrue);
    expect(await dict.containsZipResource("missing.mp3"), isFalse);
  });

  test("reads numbered packs in order", () async {
    await File("${dir.path}/oxford.zip").writeAsBytes(
      _zipBytes({
        "first.mp3": [1],
      }),
    );
    await File("${dir.path}/oxford.1.zip").writeAsBytes(
      _zipBytes({
        "second.mp3": [2],
      }),
    );
    await File("${dir.path}/oxford.2.zip").writeAsBytes(
      _zipBytes({
        "third.mp3": [3],
      }),
    );

    expect(await dict.readZipResource("first.mp3"), [1]);
    expect(await dict.readZipResource("second.mp3"), [2]);
    expect(await dict.readZipResource("third.mp3"), [3]);
  });

  test("a gap in the numbering ends the sequence, like .mdd parts", () async {
    await File("${dir.path}/oxford.1.zip").writeAsBytes(
      _zipBytes({
        "second.mp3": [2],
      }),
    );

    expect(await dict.readZipResource("second.mp3"), isNull);
  });

  test("returns null when no pack exists", () async {
    expect(await dict.readZipResource("hello.mp3"), isNull);
    expect(await dict.containsZipResource("hello.mp3"), isFalse);
  });

  test("refuses entries escaping the archive root", () async {
    await File("${dir.path}/oxford.zip").writeAsBytes(
      _zipBytes({
        "../evil.mp3": [1],
      }),
    );

    expect(await dict.readZipResource("../evil.mp3"), isNull);
    expect(await dict.readZipResource("evil.mp3"), isNull);
  });
}

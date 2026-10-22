import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/repositories/stardict.dart";
import "package:flutter_test/flutter_test.dart";

/// Writes a minimal StarDict dictionary (ifo/idx/dict/syn) into [dir] and
/// returns its base path. Entries use embedded type markers.
Future<String> writeFixture(Directory dir) async {
  final entries = <String, List<int>>{
    "apple": _entry([("m", "a fruit"), ("t", "'æpl")]),
    "banana": _entry([
      ("x", "<xdxf><k>banana</k><def><dtrn>香蕉</dtrn></def></xdxf>"),
    ]),
  };

  final dictBytes = BytesBuilder();
  final idx = BytesBuilder();
  var index = 0;
  final wordIndex = <String, int>{};
  for (final word in entries.keys) {
    wordIndex[word] = index++;
    final data = entries[word]!;
    idx.add(utf8.encode(word));
    idx.addByte(0);
    idx.add(
      (ByteData(
        4,
      )..setUint32(0, dictBytes.length, Endian.big)).buffer.asUint8List(),
    );
    idx.add(
      (ByteData(4)..setUint32(0, data.length, Endian.big)).buffer.asUint8List(),
    );
    dictBytes.add(data);
  }

  final syn = BytesBuilder()
    ..add(utf8.encode("fruit"))
    ..addByte(0)
    ..add(
      (ByteData(
        4,
      )..setUint32(0, wordIndex["apple"]!, Endian.big)).buffer.asUint8List(),
    );

  final base = "${dir.path}/fixture";
  await File("$base.dict").writeAsBytes(dictBytes.takeBytes());
  await File("$base.idx").writeAsBytes(idx.takeBytes());
  await File("$base.syn").writeAsBytes(syn.takeBytes());
  await File("$base.ifo").writeAsString(
    "StarDict's dict ifo file\n"
    "version=2.4.2\n"
    "bookname=Fixture Dictionary\n"
    "wordcount=2\n"
    "synwordcount=1\n"
    "description=Fixture description\n",
  );
  return base;
}

List<int> _entry(List<(String, String)> fields) {
  final out = BytesBuilder();
  for (final (type, text) in fields) {
    out.addByte(type.codeUnitAt(0));
    out.add(utf8.encode(text));
    out.addByte(0);
  }
  return out.takeBytes();
}

void main() {
  late Directory dir;
  late Stardict dict;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp("stardict_app_test");
    final base = await writeFixture(dir);
    dict = Stardict(path: base)..id = 42;
    await dict.init();
  });

  tearDown(() async {
    await dict.close();
    await dir.delete(recursive: true);
  });

  test("loads and reports ready with a desktop content server", () {
    expect(dict.isReady, isTrue);
    expect(dict.port, isNot(0));
    expect(dict.description, "Fixture description");
  });

  test("resolveExactKey handles exact, lowercase and synonyms", () async {
    expect(await dict.resolveExactKey("apple"), "apple");
    expect(await dict.resolveExactKey("APPLE"), "apple");
    expect(await dict.resolveExactKey("fruit"), "apple");
    expect(await dict.resolveExactKey("missing"), isNull);
  });

  test("search returns prefix suggestions including synonyms", () async {
    expect(await dict.search("app"), ["apple"]);
    expect(await dict.search("fr"), ["fruit"]);
    expect(await dict.search("zzz"), isEmpty);
  });

  test("readExactEntries converts fields to HTML", () async {
    final entries = await dict.readExactEntries(["apple", "banana", "nope"]);
    expect(entries, hasLength(2));
    expect(entries[0].headword, "apple");
    expect(entries[0].content, contains("a fruit"));
    expect(entries[0].content, contains("[&#39;æpl]"));
    expect(entries[1].headword, "banana");
    expect(entries[1].content, contains("香蕉"));
  });

  test("wrapContentWithResources leaves StarDict HTML untouched", () {
    expect(dict.wrapContentWithResources("<p>x</p>"), "<p>x</p>");
  });
}

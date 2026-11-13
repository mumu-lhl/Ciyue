import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/stardict.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path_provider_platform_interface/path_provider_platform_interface.dart";

/// A [PathProviderPlatform] that answers the application cache directory
/// from a test-owned temp dir. The real `getApplicationCacheDirectory()`
/// throws in the test process (no binding), which the repository treats as
/// "no cache available" — so without this the `.cidx` wiring below would
/// never see a cache file.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.cacheDir);

  final Directory cacheDir;

  @override
  Future<String?> getApplicationCachePath() async => cacheDir.path;
}

/// Installs [_FakePathProviderPlatform] answering a fresh temp dir and
/// restores the previous platform afterwards.
Future<Directory> _installFakeCacheDir() async {
  final cacheDir = await Directory.systemTemp.createTemp("stardict_cache_test");
  final previous = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _FakePathProviderPlatform(cacheDir);
  addTearDown(() {
    PathProviderPlatform.instance = previous;
    cacheDir.delete(recursive: true);
  });
  return cacheDir;
}

/// Writes a minimal StarDict dictionary (ifo/idx/dict/syn) into [dir] and
/// returns its base path. Entries use embedded type markers.
Future<String> writeFixture(Directory dir, {String name = "fixture"}) async {
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

  final base = "${dir.path}/$name";
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

  test("wrapContentWithResources puts StarDict HTML in standards mode", () {
    expect(
      dict.wrapContentWithResources("<p>x</p>"),
      "<!DOCTYPE html>\n<p>x</p>",
    );
  });

  test("readExactEntries reads each distinct headword once", () async {
    final entries = await dict.readExactEntries(["apple", "Apple", "APPLE"]);

    expect(entries, hasLength(1));
    expect(entries[0].headword, "apple");
    // The lazy HTML still renders exactly as before once it is read.
    expect(entries[0].content, contains("a fruit"));
    // The structured fields are cached up front, independently of the HTML.
    expect(dict.structuredFieldsFor("apple"), isNotNull);
  });

  test(
    "readExactEntries keeps distinct spellings as separate entries",
    () async {
      // A second dictionary whose headwords differ only by capitalisation:
      // German `abend` and `Abend` are two entries, and the all-caps query
      // folds to the lowercase one, so three candidates yield two entries in
      // first-seen order.
      final words = {
        "Abend": "evening (capitalised)",
        "abend": "evening (lowercase)",
      };
      final dictBytes = BytesBuilder();
      final idx = BytesBuilder();
      for (final word in words.keys) {
        final data = _entry([("m", words[word]!)]);
        idx.add(utf8.encode(word));
        idx.addByte(0);
        idx.add(
          (ByteData(
            4,
          )..setUint32(0, dictBytes.length, Endian.big)).buffer.asUint8List(),
        );
        idx.add(
          (ByteData(
            4,
          )..setUint32(0, data.length, Endian.big)).buffer.asUint8List(),
        );
        dictBytes.add(data);
      }
      final base = "${dir.path}/cases";
      await File("$base.dict").writeAsBytes(dictBytes.takeBytes());
      await File("$base.idx").writeAsBytes(idx.takeBytes());
      await File("$base.ifo").writeAsString(
        "StarDict's dict ifo file\n"
        "version=2.4.2\n"
        "bookname=Case Fixture\n"
        "wordcount=2\n",
      );

      final caseDict = Stardict(path: base)..id = 8;
      await caseDict.init();
      addTearDown(() => caseDict.close());

      final entries = await caseDict.readExactEntries([
        "abend",
        "Abend",
        "ABEND",
      ]);
      expect(entries.map((entry) => entry.headword), ["abend", "Abend"]);
      expect(entries[0].content, contains("lowercase"));
      expect(entries[1].content, contains("capitalised"));
    },
  );

  test("DictionaryEntryData.lazy builds content once, on first access", () {
    var builds = 0;
    final entry = DictionaryEntryData.lazy(
      headword: "apple",
      buildContent: () {
        builds++;
        return "<p>an apple</p>";
      },
    );

    expect(builds, 0);
    expect(entry.content, "<p>an apple</p>");
    expect(builds, 1);
    expect(entry.content, "<p>an apple</p>");
    expect(builds, 1);
  });

  test("links a stylesheet named after the dictionary", () async {
    final cssDir = await Directory.systemTemp.createTemp("stardict_css_test");
    addTearDown(() => cssDir.delete(recursive: true));
    final base = await writeFixture(cssDir);
    await File("$base.css").writeAsString("body { color: red; }");

    final withCss = Stardict(path: base)..id = 43;
    addTearDown(() => withCss.close());
    await withCss.init();

    expect(withCss.hasCss, isTrue);
    expect(
      withCss.wrapContentWithResources("<p>x</p>"),
      '<!DOCTYPE html>\n<link rel="stylesheet" href="fixture.css">\n<p>x</p>',
    );
    expect(await withCss.readResourceFile("fixture.css"), isNotNull);
  });

  test("percent-encodes a non-ASCII stylesheet name", () async {
    final cssDir = await Directory.systemTemp.createTemp("stardict_css_zh");
    addTearDown(() => cssDir.delete(recursive: true));
    final base = await writeFixture(cssDir, name: "中文词典");
    await File("$base.css").writeAsString("body { color: red; }");

    final withCss = Stardict(path: base)..id = 44;
    addTearDown(() => withCss.close());
    await withCss.init();

    expect(withCss.hasCss, isTrue);
    expect(
      withCss.wrapContentWithResources("<p>x</p>"),
      contains('href="${Uri.encodeComponent("中文词典")}.css"'),
    );
    // Both the desktop server and the Android path handler decode the request
    // path before it reaches the dictionary.
    expect(await withCss.readResourceFile("中文词典.css"), isNotNull);
  });

  test("structured fields are cached for entries read by lookup", () async {
    await dict.readExactEntries(["apple", "banana"]);

    final apple = dict.structuredFieldsFor("apple");
    expect(apple, isNotNull);
    expect(apple!.map((field) => field.type), ["m", "t"]);
    final banana = dict.structuredFieldsFor("banana");
    expect(banana!.single.type, "x");
    expect(dict.structuredFieldsFor("missing"), isNull);
  });

  test("binary-only entries do not count as found", () async {
    // A second dictionary whose only entry carries a binary field ('W'):
    // it has nothing displayable and must not produce a blank section.
    final dictBytes = BytesBuilder()
      ..addByte(0x57) // 'W'
      ..add((ByteData(4)..setUint32(0, 3, Endian.big)).buffer.asUint8List())
      ..add([1, 2, 3]);
    final data = dictBytes.takeBytes();
    final idx = BytesBuilder()
      ..add(utf8.encode("soundonly"))
      ..addByte(0)
      ..add((ByteData(4)..setUint32(0, 0, Endian.big)).buffer.asUint8List())
      ..add(
        (ByteData(
          4,
        )..setUint32(0, data.length, Endian.big)).buffer.asUint8List(),
      );
    final base = "${dir.path}/binary";
    await File("$base.dict").writeAsBytes(data);
    await File("$base.idx").writeAsBytes(idx.takeBytes());
    await File("$base.ifo").writeAsString(
      "StarDict's dict ifo file\n"
      "version=2.4.2\n"
      "bookname=Binary Fixture\n"
      "wordcount=1\n",
    );

    final binaryDict = Stardict(path: base)..id = 7;
    await binaryDict.init();
    expect(await binaryDict.readExactEntries(["soundonly"]), isEmpty);
    expect(binaryDict.structuredFieldsFor("soundonly"), isNull);
    await binaryDict.close();
  });

  test("writes a .cidx cache on init and reuses it on cold start", () async {
    final cacheDir = await _installFakeCacheDir();
    final cacheFile = File("${cacheDir.path}/dict_reader_142_stardict.cidx");

    final base = await writeFixture(dir, name: "cached");
    final first = Stardict(path: base)..id = 142;
    addTearDown(() => first.close());
    await first.init();

    expect(await cacheFile.exists(), isTrue);
    final cacheBytes = await cacheFile.readAsBytes();
    expect(String.fromCharCodes(cacheBytes.take(4)), "SDIX");

    // Rewrite the `.idx` so a full parse would see different words, but
    // keep the fingerprint (size and mtime) and every entry offset intact.
    // The swap also moves the first word after the second in sort order:
    // the cached search order still puts it first, so the binary search
    // over the live words misses even the unchanged "banana" — only an
    // index restored from the cache can behave this way.
    final idxFile = File("$base.idx");
    final idxStat = await idxFile.stat();
    final idxBytes = await idxFile.readAsBytes();
    expect(String.fromCharCodes(idxBytes.take(5)), "apple");
    idxBytes.setRange(0, 5, utf8.encode("zebra"));
    await idxFile.writeAsBytes(idxBytes, flush: true);
    await idxFile.setLastModified(idxStat.modified);

    final second = Stardict(path: base)..id = 142;
    addTearDown(() => second.close());
    await second.init();

    expect(await second.search("banana"), isEmpty);
    expect(await second.search("zebra"), isEmpty);
    // The dictionary itself is still alive off the cached index: the
    // synonym resolves to the first entry, whose live spelling is "zebra".
    expect(await second.resolveExactKey("fruit"), "zebra");
  });

  test("falls back to a full parse when the cache is stale", () async {
    final cacheDir = await _installFakeCacheDir();
    final cacheFile = File("${cacheDir.path}/dict_reader_143_stardict.cidx");

    final base = await writeFixture(dir, name: "stale");
    final first = Stardict(path: base)..id = 143;
    addTearDown(() => first.close());
    await first.init();
    expect(await cacheFile.exists(), isTrue);
    final firstCacheBytes = await cacheFile.readAsBytes();

    // The same word swap as above, but the write updates the `.idx` mtime,
    // so the fingerprint no longer matches and the cache must be ignored.
    final idxFile = File("$base.idx");
    final idxBytes = await idxFile.readAsBytes();
    idxBytes.setRange(0, 5, utf8.encode("zebra"));
    await idxFile.writeAsBytes(idxBytes, flush: true);

    final second = Stardict(path: base)..id = 143;
    addTearDown(() => second.close());
    await second.init();

    expect(await second.search("banana"), ["banana"]);
    expect(await second.search("zebra"), ["zebra"]);
    // A full parse rebuilt the index from the new `.idx`, so the old word
    // is gone entirely — the stale snapshot was not consulted.
    expect(await second.resolveExactKey("apple"), isNull);
    expect(await second.resolveExactKey("zebra"), "zebra");
    final entries = await second.readExactEntries(["zebra"]);
    expect(entries, hasLength(1));
    expect(entries.first.content, contains("a fruit"));
    // The stale snapshot was replaced by a fresh export of the new index.
    expect(await cacheFile.readAsBytes(), isNot(firstCacheBytes));
  });

  test("falls back to a full parse when the cache bytes are invalid", () async {
    final cacheDir = await _installFakeCacheDir();
    final cacheFile = File("${cacheDir.path}/dict_reader_144_stardict.cidx");

    final base = await writeFixture(dir, name: "corrupt");
    final first = Stardict(path: base)..id = 144;
    addTearDown(() => first.close());
    await first.init();
    expect(await cacheFile.exists(), isTrue);

    await cacheFile.writeAsBytes(utf8.encode("not a cidx"), flush: true);

    final second = Stardict(path: base)..id = 144;
    addTearDown(() => second.close());
    await second.init();

    expect(second.isReady, isTrue);
    expect(await second.search("app"), ["apple"]);
    // The corrupt snapshot was replaced by a valid export.
    expect(
      String.fromCharCodes((await cacheFile.readAsBytes()).take(4)),
      "SDIX",
    );
  });

  test("removing the dictionary deletes its .cidx cache", () async {
    final cacheDir = await _installFakeCacheDir();
    final cacheFile = File("${cacheDir.path}/dict_reader_145_stardict.cidx");

    final base = await writeFixture(dir, name: "removable");
    final removable = Stardict(path: base)..id = 145;
    addTearDown(() => removable.close());
    await removable.init();
    expect(await cacheFile.exists(), isTrue);

    await removable.onRemove();
    expect(await cacheFile.exists(), isFalse);
  });
}

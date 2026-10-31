import "dart:io";

import "package:ciyue/repositories/zim.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;

import "zim_fixture.dart";

Future<String> writeTestZimFixture(Directory dir) async {
  final builder = ZimFixtureBuilder();
  builder.addMetadata("Title", "Wikipedia Sample");
  builder.addMetadata("Description", "A small sample encyclopedia");
  builder.addMetadata("Language", "eng");
  builder.addMetadata("Date", "2026-10-31");

  builder.addArticle(
    "Apple",
    "Apple",
    "<h1>Apple</h1><p>A delicious fruit.</p><img src=\"I/apple.png\" />",
  );
  builder.addArticle(
    "Banana",
    "Banana",
    "<h1>Banana</h1><p>A yellow fruit.</p>",
  );
  builder.addRedirect("fruit", "fruit", "Apple");
  builder.addResource(
    "apple.png",
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    "image/png",
    namespace: "I",
  );

  final filePath = await builder.write(dir, "sample");
  return filePath.replaceAll(RegExp(r"\.zim$"), "");
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late Zim dict;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp("zim_app_test");
    final base = await writeTestZimFixture(dir);
    dict = Zim(path: base)..id = 100;
    await dict.init();
  });

  tearDown(() async {
    await dict.close();
    await dir.delete(recursive: true);
  });

  test("loads metadata and reports ready with desktop server", () {
    expect(dict.isReady, isTrue);
    expect(dict.port, isNot(0));
    expect(dict.title, "Wikipedia Sample");
    expect(dict.description, contains("A small sample encyclopedia"));
  });

  test(
    "resolveExactKey resolves exact match, case variations, and redirects",
    () async {
      expect(await dict.resolveExactKey("Apple"), "Apple");
      expect(await dict.resolveExactKey("apple"), "Apple");
      expect(await dict.resolveExactKey("fruit"), "Apple");
      expect(await dict.resolveExactKey("Nonexistent"), isNull);
    },
  );

  test("search finds prefix suggestions", () async {
    final results = await dict.search("app");
    expect(results, contains("Apple"));

    final bananaResults = await dict.search("ban");
    expect(bananaResults, contains("Banana"));

    final fruitResults = await dict.search("fru");
    expect(fruitResults, contains("fruit"));

    final missing = await dict.search("zzz");
    expect(missing, isEmpty);
  });

  test("readExactEntries reads article html and wrapContentWithResources preserves html", () async {
    final entries = await dict.readExactEntries(["Apple"]);
    expect(entries, hasLength(1));
    expect(entries.first.headword, "Apple");
    expect(entries.first.content, contains("A delicious fruit."));
    expect(entries.first.content, contains('<img src="I/apple.png" />'));

    final html = dict.wrapContentWithResources(entries.first.content);
    expect(html, contains('<img src="I/apple.png" />'));
  });

  test("desktop http server serves ZIM resources", () async {
    final prev = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      final response = await http.get(
        Uri.parse("http://127.0.0.1:${dict.port}/I/apple.png"),
      );
      expect(response.statusCode, 200);
      expect(response.headers["content-type"], contains("image/png"));
      expect(
        response.bodyBytes,
        equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      );
    } finally {
      HttpOverrides.global = prev;
    }
  });
}

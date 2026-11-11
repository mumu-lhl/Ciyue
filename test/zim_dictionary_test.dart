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
    "<h1>Apple</h1>"
        "<p>A delicious <a href=\"Banana\">fruit</a>.</p>"
        "<a href=\"Banana#section\">section</a>"
        "<a href=\"fruit\">redirect</a>"
        "<a href=\"style\">stylesheet link</a>"
        "<a href=\"I/apple.png\">image link</a>"
        "<a href=\"./_mw_/site.css\">missing stylesheet</a>"
        "<a href=\"#cite_note-1\">footnote</a>"
        "<a href=\"https://example.com/Apple\">external</a>"
        "<a href=\"A:B@C\">odd name</a>"
        "<a href=\"I/voice.ogg\">listen</a>"
        "<a href=\"Missing_Page\">missing</a>"
        "<a href=\"../A/Gone_Entry\">gone</a>"
        "<a href=\"entry://SomeWord\">entry scheme</a>"
        "<a href=\"geo:40.2,44.7\">geo</a>"
        "<img src=\"I/apple.png\" />",
  );
  builder.addArticle(
    "Banana",
    "Banana",
    "<h1>Banana</h1><p>A yellow fruit.</p>",
  );
  builder.addArticle(
    "A:B@C",
    "A:B@C",
    "<h1>A:B@C</h1><p>A name made of URL punctuation.</p>",
  );
  builder.addRedirect("fruit", "fruit", "Apple");
  builder.addResource(
    "apple.png",
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    "image/png",
    namespace: "I",
  );
  // No extension on purpose: only the entry's own MIME type identifies it.
  builder.addResource("style", [0x62, 0x6F, 0x64, 0x79], "text/css");
  builder.addResource(
    "voice.ogg",
    [0x4F, 0x67, 0x67, 0x53],
    "audio/ogg",
    namespace: "I",
  );

  final filePath = await builder.write(dir, "sample");
  return filePath.replaceAll(RegExp(r"\.zim$"), "");
}

/// A fixture where non-article entries share the ordering with articles:
/// new-namespace (C) articles with media in the same namespace, plus a
/// layout entry in the '-' namespace sorting before them. Entry indices and
/// article indices diverge here, which is what regressed resolveKeys.
Future<String> writeMixedNamespaceZimFixture(Directory dir) async {
  final builder = ZimFixtureBuilder();
  builder.addMetadata("Title", "Mixed Namespaces");
  builder.addArticle("Apple", "Apple", "<p>apple</p>", namespace: "C");
  builder.addResource(
    "Apple.jpg",
    [0x01, 0x02, 0x03],
    "image/jpeg",
    namespace: "C",
  );
  builder.addArticle("Banana", "Banana", "<p>banana</p>", namespace: "C");
  builder.addResource(
    "style.css",
    [0x62, 0x6f, 0x64, 0x79, 0x7b, 0x7d],
    "text/css",
    namespace: "-",
  );
  builder.addRedirect(
    "fruit",
    "fruit",
    "Apple",
    namespace: "C",
    targetNamespace: "C",
  );

  final filePath = await builder.write(dir, "mixed");
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

  test(
    "resolveExactKey stays correct when non-article entries share ordering",
    () async {
      final mixedDir = await Directory.systemTemp.createTemp("zim_mixed_test");
      try {
        final base = await writeMixedNamespaceZimFixture(mixedDir);
        final mixed = Zim(path: base)..id = 101;
        await mixed.init();
        try {
          expect(await mixed.resolveExactKey("Apple"), "Apple");
          expect(await mixed.resolveExactKey("Banana"), "Banana");
          expect(await mixed.resolveExactKey("apple"), "Apple");
          expect(await mixed.resolveExactKey("fruit"), "Apple");
          expect(await mixed.resolveExactKey("Nonexistent"), isNull);
        } finally {
          await mixed.close();
        }
      } finally {
        await mixedDir.delete(recursive: true);
      }
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
    expect(entries.first.content, contains("A delicious"));
    expect(entries.first.content, contains('<img src="I/apple.png" />'));

    final html = dict.wrapContentWithResources(entries.first.content);
    expect(html, contains('<img src="I/apple.png" />'));
  });

  test("rewrites ZIM article links into gdlookup entry links", () async {
    final entries = await dict.readExactEntries(["Apple"]);
    final html = entries.single.content;

    expect(html, contains('href="gdlookup://localhost/%42%61%6E%61%6E%61"'));
    expect(
      html,
      contains(
        'href="gdlookup://localhost/%42%61%6E%61%6E%61'
        '?gdanchor=%73%65%63%74%69%6F%6E"',
      ),
    );
    expect(html, contains('href="gdlookup://localhost/%66%72%75%69%74"'));
    // `:` and `@` are legal entry-name characters; the whole name is encoded
    // byte by byte so the URI parser cannot read `A:` as a scheme.
    expect(html, contains('href="gdlookup://localhost/%41%3A%42%40%43"'));
    // Audio entries become sound:// so a tap plays them instead of navigating
    // to a resource URL.
    expect(
      html,
      contains('href="sound://localhost/%49%2F%76%6F%69%63%65%2E%6F%67%67"'),
    );
    // A path the archive does not answer is still a lookup: the reader gets
    // the not-found page instead of a bare 404. Kiwix slugs (`_`) become
    // spaces, and `../A/Foo` is reduced to its last segment.
    expect(
      html,
      contains(
        'href="gdlookup://localhost/%4D%69%73%73%69%6E%67%20%50%61%67%65"',
      ),
    );
    expect(
      html,
      contains('href="gdlookup://localhost/%47%6F%6E%65%20%45%6E%74%72%79"'),
    );
    expect(html, contains('href="entry://SomeWord"'));
    // Real Wikipedia ZIMs emit geo: coordinate links; they are external
    // protocols, not dead article paths.
    expect(html, contains('href="geo:40.2,44.7"'));

    // Resources, pure anchors, external URLs and images stay as authored.
    for (final untouched in [
      'href="style"',
      'href="I/apple.png"',
      'href="./_mw_/site.css"',
      'href="#cite_note-1"',
      'href="https://example.com/Apple"',
      '<img src="I/apple.png" />',
    ]) {
      expect(html, contains(untouched), reason: untouched);
    }

    expect(
      dict.wrapContentWithResources(html),
      contains('href="gdlookup://localhost/%42%61%6E%61%6E%61"'),
    );
  });

  test("resolves local article paths back to headwords", () async {
    expect(await dict.entryTitleAtPath("Banana"), "Banana");
    expect(await dict.entryTitleAtPath("fruit"), "fruit");
    expect(await dict.entryTitleAtPath("I/voice.ogg"), isNull);
    expect(await dict.entryTitleAtPath("Missing_Page"), isNull);
  });

  test("desktop http server answers with the ZIM entry mime type", () async {
    final prev = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      final article = await http.get(
        Uri.parse("http://127.0.0.1:${dict.port}/Banana"),
      );
      expect(article.statusCode, 200);
      expect(article.headers["content-type"], contains("text/html"));

      final stylesheet = await http.get(
        Uri.parse("http://127.0.0.1:${dict.port}/style"),
      );
      expect(stylesheet.statusCode, 200);
      expect(stylesheet.headers["content-type"], contains("text/css"));

      final audio = await http.get(
        Uri.parse("http://127.0.0.1:${dict.port}/I/voice.ogg"),
      );
      expect(audio.statusCode, 200);
      expect(audio.headers["content-type"], contains("audio/ogg"));
    } finally {
      HttpOverrides.global = prev;
    }
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

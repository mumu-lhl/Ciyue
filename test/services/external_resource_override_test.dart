import "dart:io";

import "package:ciyue/repositories/dictionary.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  group("externalOverrideFileName", () {
    test("accepts plain css and js file names", () {
      expect(externalOverrideFileName("daijirin2.css"), "daijirin2.css");
      expect(externalOverrideFileName("reader.js"), "reader.js");
      expect(externalOverrideFileName("STYLE.CSS"), "STYLE.CSS");
    });

    test("strips a leading slash or backslash", () {
      expect(externalOverrideFileName("/daijirin2.css"), "daijirin2.css");
      expect(externalOverrideFileName("\\daijirin2.css"), "daijirin2.css");
    });

    test("rejects non-css/js resources", () {
      expect(externalOverrideFileName("cover.png"), isNull);
      expect(externalOverrideFileName("font.ttf"), isNull);
      expect(externalOverrideFileName("sound.mp3"), isNull);
      expect(externalOverrideFileName("style.css.bak"), isNull);
    });

    test("rejects paths with separators or traversal segments", () {
      expect(externalOverrideFileName("res/style.css"), isNull);
      expect(externalOverrideFileName("res\\style.css"), isNull);
      expect(externalOverrideFileName("../evil.css"), isNull);
      expect(externalOverrideFileName("..\\evil.css"), isNull);
      expect(externalOverrideFileName("notes..css"), isNull);
      expect(externalOverrideFileName(""), isNull);
      expect(externalOverrideFileName("/"), isNull);
    });
  });

  group("readExternalResourceOverride", () {
    late Directory dir;
    late String dictPath;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp("ciyue_override_test");
      dictPath = p.join(dir.path, "dict.mdx");
      await File(dictPath).writeAsBytes([0]);
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test("returns the external file bytes when it exists", () async {
      await File(p.join(dir.path, "theme.css")).writeAsString("body {}");
      final bytes = await readExternalResourceOverride(dictPath, "theme.css");
      expect(bytes, isNotNull);
      expect(String.fromCharCodes(bytes!), "body {}");
    });

    test(
      "finds the file when the resource path has a leading backslash",
      () async {
        await File(p.join(dir.path, "theme.css")).writeAsString("body {}");
        final bytes = await readExternalResourceOverride(
          dictPath,
          "\\theme.css",
        );
        expect(bytes, isNotNull);
      },
    );

    test("returns null when there is no external file", () async {
      expect(await readExternalResourceOverride(dictPath, "theme.css"), isNull);
    });

    test(
      "returns null for non-overridable resources even when present",
      () async {
        await File(p.join(dir.path, "cover.png")).writeAsBytes([1, 2, 3]);
        expect(
          await readExternalResourceOverride(dictPath, "cover.png"),
          isNull,
        );
      },
    );
  });
}

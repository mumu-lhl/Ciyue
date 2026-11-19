import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late AppDatabase database;
  late PersonalDictionaryService service;
  late DictionaryListDao dictionaryListDao;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    service = PersonalDictionaryService(database);
    dictionaryListDao = DictionaryListDao(database);
  });

  tearDown(() => database.close());

  group("createDictionary", () {
    test("creates a type 4 row with the sentinel path", () async {
      final id = await service.createDictionary("My Words");

      expect(await dictionaryListDao.getType(id), DictionaryType.personal);
      expect(await dictionaryListDao.getPath(id), "personal:$id");
      expect(await dictionaryListDao.getTitle(id), "My Words");
    });

    test("rejects a blank name", () async {
      await expectLater(service.createDictionary("   "), throwsArgumentError);
    });
  });

  group("renameDictionary and deleteDictionary", () {
    test("rename updates the title", () async {
      final id = await service.createDictionary("Old");

      await service.renameDictionary(id, "New");

      expect(await dictionaryListDao.getTitle(id), "New");
    });

    test("deleteDictionary removes articles, headwords and the row", () async {
      final id = await service.createDictionary("Doomed");
      await service.createEntry(id, headwords: ["apple"], body: "a fruit");

      await service.deleteDictionary(id);

      expect(await dictionaryListDao.getById(id), isNull);
      expect(await service.entryCount(id), 0);
    });

    test("rename and delete reject a non-personal dictionary", () async {
      final id = await dictionaryListDao.add("/tmp/not-personal", "MDict");

      await expectLater(service.renameDictionary(id, "X"), throwsStateError);
      await expectLater(service.deleteDictionary(id), throwsStateError);
      await expectLater(
        service.createEntry(id, headwords: ["a"], body: "b"),
        throwsStateError,
      );
      expect(await dictionaryListDao.getById(id), isNotNull);
    });
  });

  group("entries", () {
    test(
      "createEntry and listEntries round-trip, ordered by headword",
      () async {
        final id = await service.createDictionary("Words");
        await service.createEntry(id, headwords: ["banana"], body: "yellow");
        await service.createEntry(id, headwords: ["apple"], body: "red");

        final entries = await service.listEntries(id);

        expect(entries.map((e) => e.headwords.single), ["apple", "banana"]);
        expect(entries.first.body, "red");
        expect(entries.first.dictionaryId, id);
        expect(entries.first.articleId, isNonZero);
        expect(await service.entryCount(id), 2);
      },
    );

    test("aliases share one article: edit once, visible under all", () async {
      final id = await service.createDictionary("Words");
      final articleId = await service.createEntry(
        id,
        headwords: ["color", "colour"],
        body: "v1",
      );

      await service.updateEntry(
        articleId,
        headwords: ["color", "colour"],
        body: "v2",
      );

      final entries = await service.listEntries(id);
      expect(entries, hasLength(1));
      expect(entries.single.headwords, ["color", "colour"]);
      expect(entries.single.body, "v2");
      expect(await service.entryCount(id), 2);
    });

    test("updateEntry can rename headwords", () async {
      final id = await service.createDictionary("Words");
      final articleId = await service.createEntry(
        id,
        headwords: ["old"],
        body: "body",
      );

      await service.updateEntry(articleId, headwords: ["new"], body: "body");

      expect((await service.listEntries(id)).single.headwords, ["new"]);
      expect(await service.entryCount(id), 1);
    });

    test("createEntry trims headwords and drops empties", () async {
      final id = await service.createDictionary("Words");
      final articleId = await service.createEntry(
        id,
        headwords: ["  apple  ", "", "  "],
        body: "body",
      );

      final entries = await service.listEntries(id);
      expect(entries.single.articleId, articleId);
      expect(entries.single.headwords, ["apple"]);
    });

    test(
      "createEntry rejects empty headwords, empty body and duplicates",
      () async {
        final id = await service.createDictionary("Words");

        await expectLater(
          service.createEntry(id, headwords: [], body: "body"),
          throwsArgumentError,
        );
        await expectLater(
          service.createEntry(id, headwords: ["  "], body: "body"),
          throwsArgumentError,
        );
        await expectLater(
          service.createEntry(id, headwords: ["apple"], body: "  "),
          throwsArgumentError,
        );

        await service.createEntry(id, headwords: ["Apple"], body: "one");
        await expectLater(
          service.createEntry(id, headwords: ["apple"], body: "two"),
          throwsStateError,
        );
        await expectLater(
          service.createEntry(id, headwords: ["APPLE"], body: "three"),
          throwsStateError,
        );
      },
    );

    test("updateEntry rejects a headword owned by another article", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(id, headwords: ["apple"], body: "one");
      final other = await service.createEntry(
        id,
        headwords: ["banana"],
        body: "two",
      );

      await expectLater(
        service.updateEntry(other, headwords: ["Apple"], body: "two"),
        throwsStateError,
      );
    });

    test("updateEntry and deleteEntry reject an unknown article", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(id, headwords: ["apple"], body: "one");

      await expectLater(
        service.updateEntry(9999, headwords: ["x"], body: "y"),
        throwsStateError,
      );
      await expectLater(service.deleteEntry(9999), throwsStateError);
    });

    test("deleteEntry removes the article and its headwords", () async {
      final id = await service.createDictionary("Words");
      final articleId = await service.createEntry(
        id,
        headwords: ["apple", "apples"],
        body: "body",
      );
      await service.createEntry(id, headwords: ["banana"], body: "body");

      await service.deleteEntry(articleId);

      expect(await service.entryCount(id), 1);
      expect((await service.listEntries(id)).single.headwords, ["banana"]);
    });

    test("listEntries query filters by normalized prefix", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(id, headwords: ["Apple"], body: "a");
      await service.createEntry(id, headwords: ["application"], body: "b");
      await service.createEntry(id, headwords: ["banana"], body: "c");

      expect(
        (await service.listEntries(
          id,
          query: "APP",
        )).map((e) => e.headwords.single),
        ["Apple", "application"],
      );
      expect(
        (await service.listEntries(
          id,
          query: "banana",
        )).map((e) => e.headwords.single),
        ["banana"],
      );
      expect(await service.listEntries(id, query: "zzz"), isEmpty);
    });

    test("headwords fold NFC and case", () async {
      final id = await service.createDictionary("Words");
      // "émile" stored decomposed: e + combining acute (U+0301).
      await service.createEntry(id, headwords: ["émile"], body: "name");

      // Queried composed (U+00C9) and upper-cased: still the same entry,
      // and the stored spelling comes back exactly as it was written.
      expect(
        (await service.listEntries(
          id,
          query: "ÉMILE",
        )).map((e) => e.headwords.single),
        ["émile"],
      );
    });
  });

  group("DSL export and import", () {
    const markdownBody =
        "# Title\n\nThis is **bold** and *italic* text with `code`.\n\n"
        "- one\n- two\n\n1. first\n\n[link](https://example.com) "
        "and ![alt](img.png)";

    test("exportDsl converts Markdown to the tag-free DSL subset", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(
        id,
        headwords: ["apple", "Apple fruit"],
        body: markdownBody,
      );

      final dsl = await service.exportDsl(id);

      expect(
        dsl,
        "Apple fruit\n"
        "apple\n"
        "\tTitle\n"
        "\t\n"
        "\tThis is [b]bold[/b] and [i]italic[/i] text with code.\n"
        "\t\n"
        "\t[m1]one[/m]\n"
        "\t[m1]two[/m]\n"
        "\t\n"
        "\t[m1]first[/m]\n"
        "\t\n"
        "\tlink and alt\n",
      );
    });

    test("export/import round-trips headwords and body", () async {
      final source = await service.createDictionary("Source");
      await service.createEntry(
        source,
        headwords: ["apple"],
        body: markdownBody,
      );
      await service.createEntry(
        source,
        headwords: ["banana"],
        body: "plain body",
      );
      final dsl = await service.exportDsl(source);

      final target = await service.createDictionary("Target");
      final result = await service.importDsl(target, dsl);

      expect(result.imported, 2);
      // The exported body carries DSL tags ([b], [i], [m1]); importing it
      // back warns once that they stay plain text.
      expect(result.warnings, [
        "DSL tags such as [b] are stored as plain text; "
            "formatting is not applied.",
      ]);
      final entries = await service.listEntries(target);
      expect(entries.map((e) => e.headwords.single), ["apple", "banana"]);
      expect(
        entries.first.body,
        "Title\n\nThis is [b]bold[/b] and [i]italic[/i] text with code.\n\n"
        "[m1]one[/m]\n[m1]two[/m]\n\n[m1]first[/m]\n\nlink and alt",
      );
      expect(entries.last.body, "plain body");
    });

    test(
      "importDsl stores bodies raw and warns about DSL constructs",
      () async {
        final id = await service.createDictionary("Words");
        const dsl =
            "apple\n"
            "\t[b]bold[/b] and ~tilde~ (note) {{meta}}\n"
            "banana\n"
            "\tplain\n";

        final result = await service.importDsl(id, dsl);

        expect(result.imported, 2);
        expect(result.warnings, hasLength(4));
        expect(
          (await service.listEntries(id)).first.body,
          "[b]bold[/b] and ~tilde~ (note) {{meta}}",
        );
      },
    );

    test("importDsl skips duplicate headwords with a warning", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(id, headwords: ["apple"], body: "old");

      final result = await service.importDsl(
        id,
        "apple\n\tnew body\nbanana\n\tbody\n",
      );

      expect(result.imported, 1);
      expect(result.warnings, hasLength(1));
      expect((await service.listEntries(id)).map((e) => e.headwords.single), [
        "apple",
        "banana",
      ]);
      expect((await service.listEntries(id)).first.body, "old");
    });

    test("importDsl rejects a body line without a headword", () async {
      final id = await service.createDictionary("Words");

      await expectLater(
        service.importDsl(id, "\tbody without headword\n"),
        throwsFormatException,
      );
      expect(await service.entryCount(id), 0);
    });

    test("importDslBytes decodes UTF-16LE with a BOM", () async {
      final id = await service.createDictionary("Words");
      const dsl = "apple\n\tred fruit\nbanana\n\tyellow fruit\n";
      final bytes = _utf16Bytes(dsl, littleEndian: true, withBom: true);

      final result = await service.importDslBytes(id, bytes, "dict.dsl");

      expect(result.imported, 2);
      expect((await service.listEntries(id)).map((e) => e.headwords.single), [
        "apple",
        "banana",
      ]);
    });

    test("importDslBytes decodes UTF-16BE with a BOM", () async {
      final id = await service.createDictionary("Words");
      const dsl = "apple\n\tred fruit\n";
      final bytes = _utf16Bytes(dsl, littleEndian: false, withBom: true);

      final result = await service.importDslBytes(id, bytes, "dict.dsl");

      expect(result.imported, 1);
    });

    test("importDslBytes decodes UTF-32LE with a BOM", () async {
      final id = await service.createDictionary("Words");
      const dsl = "apple\n\tred fruit\n";
      final bytes = _utf32Bytes(dsl, littleEndian: true, withBom: true);

      final result = await service.importDslBytes(id, bytes, "dict.dsl");

      expect(result.imported, 1);
    });

    test("importDslBytes gunzips a .dz file", () async {
      final id = await service.createDictionary("Words");
      const dsl = "apple\n\tred fruit\n";
      final bytes = Uint8List.fromList(gzip.encode(utf8.encode(dsl)));

      final result = await service.importDslBytes(id, bytes, "dict.dsl.dz");

      expect(result.imported, 1);
      expect((await service.listEntries(id)).single.body, "red fruit");
    });

    test("importDslBytes gunzips on the gzip magic even without .dz", () async {
      final id = await service.createDictionary("Words");
      const dsl = "apple\n\tred fruit\n";
      final bytes = Uint8List.fromList(gzip.encode(utf8.encode(dsl)));

      final result = await service.importDslBytes(id, bytes, "dict.dsl");

      expect(result.imported, 1);
    });
  });
}

Uint8List _utf16Bytes(
  String text, {
  required bool littleEndian,
  required bool withBom,
}) {
  final units = [if (withBom) 0xFEFF, ...text.codeUnits];
  final bytes = Uint8List(units.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < units.length; i++) {
    data.setUint16(i * 2, units[i], littleEndian ? Endian.little : Endian.big);
  }
  return bytes;
}

Uint8List _utf32Bytes(
  String text, {
  required bool littleEndian,
  required bool withBom,
}) {
  final runes = [if (withBom) 0xFEFF, ...text.runes];
  final bytes = Uint8List(runes.length * 4);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < runes.length; i++) {
    data.setUint32(i * 4, runes[i], littleEndian ? Endian.little : Endian.big);
  }
  return bytes;
}

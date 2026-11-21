import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations_en.dart";
import "package:ciyue/src/generated/i18n/app_localizations_zh.dart";
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

    test("rejects a duplicate name, case-insensitively", () async {
      await service.createDictionary("My Words");

      await expectLater(service.createDictionary("my words"), throwsStateError);
      await expectLater(service.createDictionary("MY WORDS"), throwsStateError);
    });

    test("rejects a name over the length limit", () async {
      final tooLong = "a" * (personalDictionaryNameMaxLength + 1);
      await expectLater(service.createDictionary(tooLong), throwsArgumentError);
      expect(
        await service.createDictionary("a" * personalDictionaryNameMaxLength),
        isNotNull,
      );
    });

    test("dictionaryExists only matches personal dictionaries", () async {
      final id = await service.createDictionary("Words");
      final fileId = await dictionaryListDao.add("/tmp/not-personal", "MDict");

      expect(await service.dictionaryExists(id), isTrue);
      expect(await service.dictionaryExists(fileId), isFalse);
      expect(await service.dictionaryExists(999999), isFalse);
    });

    test("dictionaryNameExists matches case-insensitively", () async {
      final id = await service.createDictionary("My Words");
      await service.createDictionary("Other");

      expect(await service.dictionaryNameExists("my words"), isTrue);
      expect(await service.dictionaryNameExists("missing"), isFalse);
      expect(
        await service.dictionaryNameExists("My Words", exceptId: id),
        isFalse,
      );
    });
  });

  group("renameDictionary and deleteDictionary", () {
    test("rename updates the title", () async {
      final id = await service.createDictionary("Old");

      await service.renameDictionary(id, "New");

      expect(await dictionaryListDao.getTitle(id), "New");
    });

    test("rename to its own name is allowed", () async {
      final id = await service.createDictionary("Old");

      await service.renameDictionary(id, "old");

      expect(await dictionaryListDao.getTitle(id), "old");
    });

    test("rename rejects a duplicate name, case-insensitively", () async {
      final first = await service.createDictionary("First");
      final second = await service.createDictionary("Second");

      await expectLater(
        service.renameDictionary(second, "first"),
        throwsStateError,
      );
      expect(await dictionaryListDao.getTitle(first), "First");
      expect(await dictionaryListDao.getTitle(second), "Second");
    });

    test("rename rejects a name over the length limit", () async {
      final id = await service.createDictionary("Old");

      await expectLater(
        service.renameDictionary(
          id,
          "a" * (personalDictionaryNameMaxLength + 1),
        ),
        throwsArgumentError,
      );
      expect(await dictionaryListDao.getTitle(id), "Old");
    });

    test("deleteDictionary removes articles, headwords and the row", () async {
      final id = await service.createDictionary("Doomed");
      await service.createEntry(id, headwords: ["apple"], body: "a fruit");

      await service.deleteDictionary(id);

      expect(await dictionaryListDao.getById(id), isNull);
      // The dictionary no longer exists, so the read paths reject the id
      // instead of silently reporting an empty dictionary (P2-10).
      await expectLater(service.entryCount(id), throwsStateError);
      await expectLater(service.listEntries(id), throwsStateError);
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
      // One article with two aliases counts as one entry, not two.
      expect(await service.entryCount(id), 1);
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

    test("findConflictingHeadword reports a taken headword", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(id, headwords: ["apple"], body: "a fruit");
      await service.createEntry(id, headwords: ["banana"], body: "yellow");

      expect(await service.findConflictingHeadword(id, ["Apple"]), "apple");
      expect(await service.findConflictingHeadword(id, ["cherry"]), isNull);
    });

    test("findConflictingHeadword ignores the article being edited", () async {
      final id = await service.createDictionary("Words");
      final articleId = await service.createEntry(
        id,
        headwords: ["apple"],
        body: "a fruit",
      );
      await service.createEntry(id, headwords: ["banana"], body: "yellow");

      expect(
        await service.findConflictingHeadword(id, [
          "apple",
        ], exceptArticleId: articleId),
        isNull,
      );
      expect(
        await service.findConflictingHeadword(id, [
          "banana",
        ], exceptArticleId: articleId),
        "banana",
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
        "apple\n"
        "Apple fruit\n"
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
        const PersonalDslWarning(PersonalDslWarningKind.tags),
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
        expect(result.warnings.map((w) => w.kind).toSet(), {
          PersonalDslWarningKind.tags,
          PersonalDslWarningKind.tilde,
          PersonalDslWarningKind.parentheses,
          PersonalDslWarningKind.doubleBraces,
        });
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
      expect(result.warnings, [
        const PersonalDslWarning(PersonalDslWarningKind.duplicate, "apple"),
      ]);
      expect((await service.listEntries(id)).map((e) => e.headwords.single), [
        "apple",
        "banana",
      ]);
      expect((await service.listEntries(id)).first.body, "old");
    });

    test("importDsl rejects a body line without a headword", () async {
      final id = await service.createDictionary("Words");

      // An orphan body line is skipped with a warning instead of voiding
      // the whole file (P1-11): the valid entry still imports.
      final result = await service.importDsl(
        id,
        "\tbody without headword\napple\n\tred fruit\n",
      );

      expect(result.imported, 1);
      expect(result.warnings, [
        const PersonalDslWarning(PersonalDslWarningKind.orphanBodyLines, "", 1),
      ]);
      expect((await service.listEntries(id)).single.headwords, ["apple"]);
    });

    test("import warnings render as localised messages", () {
      final l10n = AppLocalizationsEn();
      expect(
        const PersonalDslWarning(PersonalDslWarningKind.tags).message(l10n),
        "DSL tags such as [b] are stored as plain text; "
        "formatting is not applied.",
      );
      expect(
        const PersonalDslWarning(
          PersonalDslWarningKind.noBody,
          "apple",
        ).message(l10n),
        "Skipped entry “apple”: it has no body.",
      );
      expect(
        const PersonalDslWarning(
          PersonalDslWarningKind.duplicate,
          "apple",
        ).message(l10n),
        "Skipped entry “apple”: the headword already exists in this dictionary.",
      );
      expect(
        const PersonalDslWarning(
          PersonalDslWarningKind.orphanBodyLines,
          "",
          2,
        ).message(l10n),
        "Skipped 2 body lines without a headword.",
      );
      expect(
        const PersonalDslWarning(
          PersonalDslWarningKind.invalidEntry,
          "apple",
        ).message(l10n),
        "Skipped entry “apple”: it could not be saved.",
      );
      // The Chinese rendering carries the same headwords, not raw English.
      final zh = AppLocalizationsZh();
      expect(
        const PersonalDslWarning(
          PersonalDslWarningKind.noBody,
          "apple",
        ).message(zh),
        contains("apple"),
      );
      expect(
        const PersonalDslWarning(
          PersonalDslWarningKind.noBody,
          "apple",
        ).message(zh),
        isNot(contains("Skipped entry")),
      );
    });

    test("importDsl skips DSL metadata and comment lines", () async {
      final id = await service.createDictionary("Words");

      final result = await service.importDsl(
        id,
        "#NAME \"Test\"\n"
        "#INDEX_LANGUAGE \"English\"\n"
        "#SOURCE \"https://example.com\"\n"
        "# a comment\n"
        "apple\n"
        "\tred fruit\n",
      );

      expect(result.imported, 1);
      expect(result.warnings, isEmpty);
      expect((await service.listEntries(id)).single.headwords, ["apple"]);
    });

    test(
      "importDsl keeps a Markdown heading inside the indented body",
      () async {
        final id = await service.createDictionary("Words");

        final result = await service.importDsl(
          id,
          "apple\n\t# Title\n\ttext\n",
        );

        expect(result.imported, 1);
        expect((await service.listEntries(id)).single.body, "# Title\ntext");
      },
    );

    test("importDsl keeps blank lines inside an article body", () async {
      final id = await service.createDictionary("Words");

      final result = await service.importDsl(
        id,
        "apple\n\tpara1\n\n\tpara2\nbanana\n\tyellow\n",
      );

      expect(result.imported, 2);
      final entries = await service.listEntries(id);
      expect(entries.first.body, "para1\n\npara2");
      expect(entries.last.body, "yellow");
    });

    test(
      "importDsl skips an entry with no usable headword and keeps going",
      () async {
        final id = await service.createDictionary("Words");
        // A headword line of only a non-breaking space trims to empty, so
        // createEntry rejects it with an ArgumentError.
        final result = await service.importDsl(
          id,
          "apple\n\tred\n\u00A0\n\tbody\nbanana\n\tyellow\n",
        );

        expect(result.imported, 2);
        expect(result.warnings, [
          const PersonalDslWarning(
            PersonalDslWarningKind.invalidEntry,
            "<empty headword>",
          ),
        ]);
        expect((await service.listEntries(id)).map((e) => e.headwords.single), [
          "apple",
          "banana",
        ]);
      },
    );

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

    test("importDslBytes sniffs UTF-16LE without a BOM", () async {
      final id = await service.createDictionary("Words");
      const dsl = "apple\n\tred fruit\nbanana\n\tyellow fruit\n";
      final bytes = _utf16Bytes(dsl, littleEndian: true, withBom: false);

      final result = await service.importDslBytes(id, bytes, "dict.dsl");

      expect(result.imported, 2);
      expect((await service.listEntries(id)).map((e) => e.headwords.single), [
        "apple",
        "banana",
      ]);
    });

    test("importDslBytes sniffs UTF-16BE without a BOM", () async {
      final id = await service.createDictionary("Words");
      const dsl = "apple\n\tred fruit\n";
      final bytes = _utf16Bytes(dsl, littleEndian: false, withBom: false);

      final result = await service.importDslBytes(id, bytes, "dict.dsl");

      expect(result.imported, 1);
      expect((await service.listEntries(id)).single.body, "red fruit");
    });

    test("exportDsl keeps nested emphasis intact", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(
        id,
        headwords: ["apple"],
        body: "**bold *and italic* text**",
      );

      expect(
        await service.exportDsl(id),
        "apple\n\t[b]bold [i]and italic[/i] text[/b]\n",
      );
    });

    test("exportDsl keeps autolinks and strips other HTML tags", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(
        id,
        headwords: ["apple"],
        body: "see <https://example.com> and <b>html bold</b>",
      );

      expect(
        await service.exportDsl(id),
        "apple\n\tsee https://example.com and html bold\n",
      );
    });

    test("exportDsl keeps links whose target contains parentheses", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(
        id,
        headwords: ["apple"],
        body: "[wiki](https://en.wikipedia.org/wiki/Tea_(meal)) end",
      );

      expect(await service.exportDsl(id), "apple\n\twiki end\n");
    });
  });

  group("P2 data-layer fixes", () {
    test("concurrent createEntry with the same headword, differing only by "
        "case, reports the loser as already-exists (P2-1)", () async {
      final id = await service.createDictionary("Words");

      final results = await Future.wait([
        service
            .createEntry(id, headwords: ["dup"], body: "one")
            .then<Object?>((value) => value, onError: (Object e) => e),
        service
            .createEntry(id, headwords: ["DUP"], body: "two")
            .then<Object?>((value) => value, onError: (Object e) => e),
      ]);

      expect(results.whereType<int>(), hasLength(1));
      final errors = results.whereType<StateError>().toList();
      expect(errors, hasLength(1));
      expect(errors.single.message, contains("already exists"));
      expect(await service.entryCount(id), 1);
    });

    test("importDsl turns a case-folded duplicate into a warning, not a "
        "raw error (P2-1)", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(id, headwords: ["dup"], body: "one");

      final result = await service.importDsl(
        id,
        "DUP\n\tother body\nbanana\n\tyellow\n",
      );

      expect(result.imported, 1);
      expect(result.warnings, [
        const PersonalDslWarning(PersonalDslWarningKind.duplicate, "DUP"),
      ]);
      expect(await service.entryCount(id), 2);
    });

    test("deleteDictionary removes the id from all groups and calls the "
        "delete hook (P2-4)", () async {
      final deletedIds = <int>[];
      final hooked = PersonalDictionaryService(
        database,
        onDictionaryDeleted: (dictionaryId) async {
          deletedIds.add(dictionaryId);
        },
      );
      final id = await hooked.createDictionary("Doomed");
      await hooked.createEntry(id, headwords: ["apple"], body: "a fruit");
      final groupDao = DictGroupDao(database);
      final groupId = await groupDao.addGroup("Group", [id]);
      final otherGroupId = await groupDao.addGroup("Other", [id, 424242]);

      await hooked.deleteDictionary(id);

      expect(await groupDao.getDictIds(groupId), isEmpty);
      expect(await groupDao.getDictIds(otherGroupId), [424242]);
      expect(deletedIds, [id]);
    });

    test("listEntries orders by normalized headword, not binary spelling "
        "(P2-8)", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(id, headwords: ["Zebra"], body: "z");
      await service.createEntry(id, headwords: ["apple"], body: "a");
      await service.createEntry(id, headwords: ["Banana"], body: "b");

      expect((await service.listEntries(id)).map((e) => e.headwords.single), [
        "apple",
        "Banana",
        "Zebra",
      ]);
    });

    test("listEntries with a query returns matched entries with all their "
        "aliases (P2-9, P2-19)", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(
        id,
        headwords: ["apple", "apple fruit"],
        body: "a",
      );
      await service.createEntry(id, headwords: ["application"], body: "b");
      await service.createEntry(id, headwords: ["banana"], body: "c");

      final entries = await service.listEntries(id, query: "APP");

      expect(entries.map((e) => e.headwords), [
        ["apple", "apple fruit"],
        ["application"],
      ]);
    });

    test("articleIdsForHeadwordPrefix honors its limit (P2-9)", () async {
      final id = await service.createDictionary("Words");
      for (var i = 0; i < 5; i++) {
        await service.createEntry(id, headwords: ["word$i"], body: "b$i");
      }
      final dao = PersonalDictionaryDao(database);

      expect(
        await dao.articleIdsForHeadwordPrefix(id, "word", limit: 2),
        hasLength(2),
      );
      expect(await dao.articleIdsForHeadwordPrefix(id, "word"), hasLength(5));
      expect(await dao.articleIdsForHeadwordPrefix(id, "zzz"), isEmpty);
    });

    test("unknown dictionary ids throw a readable error instead of Bad "
        "state or silence (P2-10)", () async {
      await expectLater(
        service.renameDictionary(999999, "X"),
        throwsStateError,
      );
      await expectLater(service.deleteDictionary(999999), throwsStateError);
      await expectLater(
        service.createEntry(999999, headwords: ["a"], body: "b"),
        throwsStateError,
      );
      await expectLater(service.listEntries(999999), throwsStateError);
      await expectLater(service.entryCount(999999), throwsStateError);
      await expectLater(service.exportDsl(999999), throwsStateError);
      await expectLater(
        service.listEntries(999999),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            "message",
            contains("999999"),
          ),
        ),
      );
    });

    test(
      "createEntry and updateEntry store the body trimmed (P2-20)",
      () async {
        final id = await service.createDictionary("Words");
        final articleId = await service.createEntry(
          id,
          headwords: ["apple"],
          body: "  padded body\n\n",
        );

        expect((await service.listEntries(id)).single.body, "padded body");

        await service.updateEntry(
          articleId,
          headwords: ["apple"],
          body: "\n\nnew body  ",
        );
        expect((await service.listEntries(id)).single.body, "new body");

        // The import path goes through createEntry, so it inherits the trim.
        await service.importDsl(id, "banana\n\t  spaced body  \n");
        expect((await service.listEntries(id)).last.body, "spaced body");
      },
    );
  });

  group("P2 DSL import/export fixes", () {
    test(
      "importDsl keeps nested body indent levels distinct (P2-11)",
      () async {
        final id = await service.createDictionary("Words");

        // Space-indented nesting: the old strip-all-spaces behaviour
        // flattened level2 onto level1.
        final result = await service.importDsl(
          id,
          "apple\n"
          "    [m1]level1\n"
          "        [m2]level2\n"
          "    [m1]tabbed\n",
        );

        expect(result.imported, 1);
        expect(
          (await service.listEntries(id)).single.body,
          "[m1]level1\n    [m2]level2\n[m1]tabbed",
        );
      },
    );

    test("importDsl keeps tab-nested body levels distinct (P2-11)", () async {
      final id = await service.createDictionary("Words");

      final result = await service.importDsl(
        id,
        "apple\n"
        "\t[m1]level1\n"
        "\t\t[m2]level2\n"
        "\t[m1]tabbed\n",
      );

      expect(result.imported, 1);
      expect(
        (await service.listEntries(id)).single.body,
        "[m1]level1\n\t[m2]level2\n[m1]tabbed",
      );
    });

    test("import/export/import round-trips a body with leading and trailing "
        "blank lines (P2-12)", () async {
      final first = await service.createDictionary("First");
      // The probe body: a leading blank line, a middle blank line, and
      // trailing blank lines, written as indented empty DSL lines.
      final result = await service.importDsl(
        first,
        "apple\n"
        "\t\n"
        "\tleading blank\n"
        "\t\n"
        "\ttrailing blanks\n"
        "\t\n"
        "\t\n",
      );

      expect(result.imported, 1);
      // The store layer trims bodies (P2-20), so the leading/trailing
      // blank lines are normalised away at the first import; the middle
      // blank line survives.
      final firstBody = (await service.listEntries(first)).single.body;
      expect(firstBody, "leading blank\n\ntrailing blanks");

      // From then on the round-trip is stable: export and re-import
      // yields the identical body.
      final exported = await service.exportDsl(first);
      final second = await service.createDictionary("Second");
      final secondResult = await service.importDsl(second, exported);

      expect(secondResult.imported, 1);
      expect((await service.listEntries(second)).single.body, firstBody);
    });

    test("importDsl reports a repeated duplicate headword once, with a "
        "localised warning (P2-13)", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(id, headwords: ["apple"], body: "old");

      final result = await service.importDsl(
        id,
        "apple\n\tnew one\napple\n\tnew two\napple\n\tnew three\n",
      );

      expect(result.imported, 0);
      expect(result.warnings, [
        const PersonalDslWarning(PersonalDslWarningKind.duplicate, "apple"),
      ]);
      // The warning is the localised duplicate message, never the raw
      // exception text.
      final l10n = AppLocalizationsEn();
      for (final warning in result.warnings) {
        expect(warning.message(l10n), isNot(contains("Bad state")));
        expect(warning.message(l10n), isNot(contains("SqliteException")));
      }
      expect(await service.entryCount(id), 1);
    });

    test(
      "importDsl does not warn about parentheses in a headword (P2-14)",
      () async {
        final id = await service.createDictionary("Words");

        final result = await service.importDsl(id, "a (b)\n\tclean body\n");

        expect(result.imported, 1);
        expect(result.warnings, isEmpty);
        expect((await service.listEntries(id)).single.headwords, ["a (b)"]);
      },
    );

    test(
      "importDsl warns about @-prefixed references in the body (P2-15)",
      () async {
        final id = await service.createDictionary("Words");

        final result = await service.importDsl(
          id,
          "apple\n\t@see banana\n\tplain line\n",
        );

        expect(result.imported, 1);
        expect(result.warnings, [
          const PersonalDslWarning(PersonalDslWarningKind.atReference),
        ]);
        expect(
          const PersonalDslWarning(PersonalDslWarningKind.atReference)
              .message(AppLocalizationsEn()),
          "References such as @see are stored as plain text; "
          "they are not cross-references.",
        );

        // An @ inside a word (an email address) is not a reference.
        final other = await service.createDictionary("Other");
        final clean = await service.importDsl(
          other,
          "apple\n\tmail user@example.com for details\n",
        );
        expect(clean.imported, 1);
        expect(clean.warnings, isEmpty);
      },
    );

    test("exportDsl converts single-underscore italics but keeps snake_case "
        "(P2-16)", () async {
      final id = await service.createDictionary("Words");
      await service.createEntry(
        id,
        headwords: ["apple"],
        body: "an _x_ and _italic_ word, plus snake_case",
      );

      expect(
        await service.exportDsl(id),
        "apple\n"
        "\tan [i]x[/i] and [i]italic[/i] word, plus snake_case\n",
      );
    });

    test("importDsl signals empty input distinctly (P2-17)", () async {
      final id = await service.createDictionary("Words");

      final empty = await service.importDsl(id, "");
      expect(empty.imported, 0);
      expect(empty.warnings, isEmpty);
      expect(empty.isEmptyInput, isTrue);

      final whitespace = await service.importDsl(id, "  \n\n  \n");
      expect(whitespace.imported, 0);
      expect(whitespace.isEmptyInput, isTrue);

      final bytes = await service.importDslBytes(id, Uint8List(0), "empty.dsl");
      expect(bytes.imported, 0);
      expect(bytes.isEmptyInput, isTrue);

      // Content that imports nothing is not empty input: a metadata-only
      // file, and a file whose only entry has no body.
      final metadataOnly = await service.importDsl(id, "#NAME \"Test\"\n");
      expect(metadataOnly.imported, 0);
      expect(metadataOnly.isEmptyInput, isFalse);

      final result = await service.importDsl(id, "apple\n\tred fruit\n");
      expect(result.imported, 1);
      expect(result.isEmptyInput, isFalse);
    });

    test("importDslBytes names the file when the bytes are not valid text "
        "(P2-18)", () async {
      final id = await service.createDictionary("Words");

      await expectLater(
        service.importDslBytes(
          id,
          Uint8List.fromList([0x61, 0xFF, 0x62]),
          "broken.dsl",
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            "message",
            allOf(contains("broken.dsl"), contains("UTF-8")),
          ),
        ),
      );
    });

    test("importDslBytes names the file when a .dz file is not gzip data "
        "(P2-18)", () async {
      final id = await service.createDictionary("Words");

      await expectLater(
        service.importDslBytes(
          id,
          Uint8List.fromList(utf8.encode("apple\n\tred fruit\n")),
          "plain.dsl.dz",
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            "message",
            allOf(contains("plain.dsl.dz"), contains("decompress")),
          ),
        ),
      );
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

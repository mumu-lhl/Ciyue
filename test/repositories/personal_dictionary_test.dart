import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/personal_dictionary.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:drift/drift.dart" show driftRuntimeOptions;
import "package:drift/native.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart"
    hide expect, test, setUp, tearDown, group, expectLater;
import "package:test/test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The DictManager test opens the shared mainDatabase while each test
  // also opens its own in-memory database: expected, not a race.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel("plugins.flutter.io/path_provider"),
        (call) async => Directory.systemTemp.path,
      );

  late AppDatabase database;
  late PersonalDictionaryService service;
  late int dictionaryId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    service = PersonalDictionaryService(database);
    dictionaryId = await service.createDictionary("My Words");
    await service.createEntry(
      dictionaryId,
      headwords: ["Apple", "apple fruit"],
      body: "A **red** fruit.",
    );
    await service.createEntry(
      dictionaryId,
      headwords: ["application"],
      body: "A program.",
    );
    await service.createEntry(
      dictionaryId,
      headwords: ["banana"],
      body: "A *yellow* fruit.",
    );
  });

  tearDown(() => database.close());

  PersonalDictionary dictionary() =>
      PersonalDictionary(path: "personal:$dictionaryId", database: database);

  test("sentinel path helpers", () {
    expect(isPersonalDictionaryPath("personal:7"), isTrue);
    expect(isPersonalDictionaryPath("personal:"), isTrue);
    expect(isPersonalDictionaryPath("/tmp/dict.mdx"), isFalse);
    expect(isPersonalDictionaryPath("personal"), isFalse);
    expect(personalDictionaryIdFromPath("personal:7"), 7);
    expect(personalDictionaryIdFromPath("personal:abc"), isNull);
    expect(personalDictionaryIdFromPath("/tmp/dict.mdx"), isNull);
  });

  test("createLoadedDictionary routes type 4 to PersonalDictionary", () {
    final created = createLoadedDictionary(path: "personal:7", type: 4);

    expect(created, isA<PersonalDictionary>());
    expect(created.path, "personal:7");
  });

  test("initMetadata reads the list row and needs no files", () async {
    final dict = dictionary();

    await dict.initMetadata();

    expect(dict.id, dictionaryId);
    expect(dict.type, DictionaryType.personal);
    expect(dict.title, "My Words");
    expect(dict.entriesTotal, 4);
    expect(dict.isReady, isTrue);
    expect(dict.port, 0);
    expect(dict.description, "");
  });

  test("init starts the desktop server so entries can render", () async {
    final dict = dictionary();

    await dict.init();

    // The desktop entry WebView waits for a non-zero port before loading
    // content; without the server the word page shows the section header
    // but the entry body never loads.
    expect(dict.port, isNot(0));
    await dict.close();
    expect(dict.port, 0);
  });

  test("initMetadata rejects a missing or non-personal row", () async {
    final missing = PersonalDictionary(
      path: "personal:99999",
      database: database,
    );
    await expectLater(missing.initMetadata, throwsStateError);

    final otherId = await DictionaryListDao(database)
        .add("/tmp/not-personal", "MDict");
    final notPersonal = PersonalDictionary(
      path: "personal:$otherId",
      database: database,
    );
    await expectLater(notPersonal.initMetadata, throwsStateError);
  });

  test("search is a case-folded prefix search on headwords", () async {
    final dict = dictionary();
    await dict.init();

    expect(await dict.search("app"), ["Apple", "apple fruit", "application"]);
    expect(await dict.search("APP"), ["Apple", "apple fruit", "application"]);
    expect(await dict.search("banana"), ["banana"]);
    expect(await dict.search("zzz"), isEmpty);
    expect(await dict.search(""), isEmpty);
  });

  test("resolveExactKey folds case and NFC", () async {
    final dict = dictionary();
    await dict.init();

    expect(await dict.resolveExactKey("APPLE"), "Apple");
    expect(await dict.resolveExactKey("apple"), "Apple");
    expect(await dict.resolveExactKey("apple fruit"), "apple fruit");
    expect(await dict.resolveExactKey("missing"), isNull);
  });

  test("resolveKeys answers many candidates in one call", () async {
    final dict = dictionary();
    await dict.init();

    final resolved = await dict.resolveKeys([
      "APPLE",
      "banana",
      "missing",
      "Application",
    ]);

    expect(resolved, {
      "APPLE": "Apple",
      "banana": "banana",
      "Application": "application",
    });
  });

  test("readExactEntries converts Markdown to HTML at read time", () async {
    final dict = dictionary();
    await dict.init();

    final entries = await dict.readExactEntries(["APPLE", "banana"]);

    expect(entries.map((e) => e.headword), ["Apple", "banana"]);
    expect(entries.first.content, contains("<strong>red</strong>"));
    expect(entries.first.content, contains("<p>"));
    expect(entries.last.content, contains("<em>yellow</em>"));
  });

  test(
    "readExactEntries reads each headword once and follows aliases",
    () async {
      final dict = dictionary();
      await dict.init();

      final entries = await dict.readExactEntries([
        "apple",
        "APPLE",
        "apple fruit",
        "missing",
      ]);

      expect(entries.map((e) => e.headword), ["Apple", "apple fruit"]);
      expect(entries.first.content, entries.last.content);
    },
  );

  test("readExactEntries accepts pre-resolved keys", () async {
    final dict = dictionary();
    await dict.init();

    final entries = await dict.readExactEntries(
      ["APPLE"],
      resolvedKeys: {"APPLE": "Apple"},
    );

    expect(entries.single.headword, "Apple");
  });

  test("resource access is a no-op: no files, identity wrap, server serves nothing", () async {
    final dict = dictionary();
    await dict.init();

    expect(await dict.readResourceFile("style.css"), isNull);
    expect(dict.wrapContentWithResources("<p>x</p>"), "<p>x</p>");
    // The desktop server exists (the entry WebView needs its port), but
    // a personal dictionary serves no resources over it.
    expect(dict.port, isNot(0));
    await dict.close();
  });

  test(
    "removeDictionary deletes articles, headwords and the list row",
    () async {
      final dict = dictionary();
      await dict.init();

      await dict.removeDictionary(dictionaryId: dictionaryId);

      expect(await DictionaryListDao(database).getById(dictionaryId), isNull);
      expect(await service.entryCount(dictionaryId), 0);
      expect(await service.listEntries(dictionaryId), isEmpty);
    },
  );

  group("DictManager loading", () {
    test("a personal dictionary loads through the manager", () async {
      final globalService = PersonalDictionaryService(mainDatabase);
      final globalId = await globalService.createDictionary("Managed");
      await globalService.createEntry(
        globalId,
        headwords: ["kiwi"],
        body: "A **green** fruit.",
      );
      addTearDown(() async {
        await dictManager.close(globalId);
        try {
          await globalService.deleteDictionary(globalId);
        } catch (_) {}
      });

      await dictManager.add(globalId, "personal:$globalId");

      final dict = dictManager.dicts[globalId];
      expect(dict, isA<PersonalDictionary>());
      expect(dict!.isReady, isTrue);
      expect(dict.title, "Managed");
      expect(await dict.search("kiw"), ["kiwi"]);
      final entries = await dict.readExactEntries(["KIWI"]);
      expect(entries.single.content, contains("<strong>green</strong>"));
    });
  });
}

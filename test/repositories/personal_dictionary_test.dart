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
    expect(dict.entriesTotal, 3);
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

  test("readExactEntries completes partial resolvedKeys per word", () async {
    final id = await service.createDictionary("Kana");
    await service.createEntry(id, headwords: ["ぱそこん"], body: "hiragana");
    await service.createEntry(id, headwords: ["パソコン"], body: "katakana");
    final dict = PersonalDictionary(path: "personal:$id", database: database);
    await dict.init();

    // The lookup passes only the exact key it already resolved; the
    // other kana spelling must still be resolved, not dropped.
    final entries = await dict.readExactEntries(
      ["ぱそこん", "パソコン"],
      resolvedKeys: {"ぱそこん": "ぱそこん"},
    );

    expect(entries.map((e) => e.headword), ["ぱそこん", "パソコン"]);
    expect(
      (await dict.readExactEntries(["ぱそこん", "パソコン"])).map((e) => e.headword),
      ["ぱそこん", "パソコン"],
    );
  });

  test("resolveExactKey and search fold full-width spellings", () async {
    final id = await service.createDictionary("Width");
    await service.createEntry(id, headwords: ["ＮＨＫ"], body: "broadcaster");
    final dict = PersonalDictionary(path: "personal:$id", database: database);
    await dict.init();

    expect(await dict.resolveExactKey("NHK"), "ＮＨＫ");
    expect(await dict.resolveExactKey("ｎｈｋ"), "ＮＨＫ");
    expect(await dict.search("ｎｈ"), ["ＮＨＫ"]);

    final main = dictionary();
    await main.init();
    expect(await main.resolveExactKey("Ａpple"), "Apple");
    expect(await main.search("ａpp"), ["Apple", "apple fruit", "application"]);
  });

  test("wrapContentWithResources puts personal HTML in standards mode and "
      "rewrites media tags (P2-22)", () async {
    final dict = dictionary();
    await dict.init();

    expect(
      dict.wrapContentWithResources("<p>x</p>"),
      "<!DOCTYPE html>\n<p>x</p>",
    );
    final audio = dict.wrapContentWithResources(
      '<audio src="a.mp3">play</audio>',
    );
    expect(audio, startsWith("<!DOCTYPE html>\n"));
    expect(audio, contains('<a href="sound://a.mp3">play'));
    final video = dict.wrapContentWithResources('<video src="v.mp4">');
    expect(video, contains("<video src=\"v.mp4\" controls>"));
    await dict.close();
  });

  test("resource access is a no-op: no files, server serves nothing", () async {
    final dict = dictionary();
    await dict.init();

    expect(await dict.readResourceFile("style.css"), isNull);
    // The desktop server exists (the entry WebView needs its port), but
    // a personal dictionary serves no resources over it.
    expect(dict.port, isNot(0));
    await dict.close();
  });

  test("search propagates a database error instead of returning no results "
      "(P2-5)", () async {
    final dict = dictionary();
    await dict.init();
    await database.customStatement("DROP TABLE personal_headwords");

    await expectLater(dict.search("app"), throwsA(isA<Object>()));
    await dict.close();
  });

  test("resolveKeys and resolveExactKey trim their input (P2-6)", () async {
    final dict = dictionary();
    await dict.init();

    expect(await dict.resolveExactKey(" apple "), "Apple");
    expect(await dict.resolveExactKey("  APPLE  "), "Apple");
    expect(await dict.resolveKeys([" banana ", "missing "]), {
      " banana ": "banana",
    });
  });

  test("readExactEntries returns the same entries for a multi-alias "
      "dictionary (P2-7)", () async {
    final dict = dictionary();
    await dict.init();

    final entries = await dict.readExactEntries([
      "apple",
      "APPLE",
      "apple fruit",
      "banana",
      "missing",
    ]);

    expect(entries.map((e) => e.headword), ["Apple", "apple fruit", "banana"]);
    // The two aliases share one article: identical content.
    expect(entries[0].content, entries[1].content);
    expect(entries.first.content, contains("<strong>red</strong>"));
    expect(entries.last.content, contains("<em>yellow</em>"));
  });

  test("removeDictionary deletes articles, headwords, the list row and "
      "group membership (P2-3, P2-4)", () async {
    final dict = dictionary();
    await dict.init();
    final groupId = await DictGroupDao(database)
        .addGroup("P2 group", [dictionaryId]);

    await dict.removeDictionary(dictionaryId: dictionaryId);

    expect(await DictionaryListDao(database).getById(dictionaryId), isNull);
    // The dictionary no longer exists, so the read paths reject the id
    // instead of silently reporting an empty dictionary (P2-10).
    await expectLater(service.entryCount(dictionaryId), throwsStateError);
    await expectLater(service.listEntries(dictionaryId), throwsStateError);
    expect(await DictGroupDao(database).getDictIds(groupId), isEmpty);
  });

  group("sanitizePersonalDictionaryHtml", () {
    test("strips script tags and their content", () {
      expect(
        sanitizePersonalDictionaryHtml(
          "<p>safe</p><script>alert(1)</script><p>after</p>",
        ),
        "<p>safe</p><p>after</p>",
      );
      expect(
        sanitizePersonalDictionaryHtml("<SCRIPT>alert(1)</SCRIPT>safe"),
        "safe",
      );
      expect(
        sanitizePersonalDictionaryHtml("<scr<script>ipt>alert(1)</script>safe"),
        isNot(contains("alert(")),
      );
      expect(
        sanitizePersonalDictionaryHtml("<script>alert(1)"),
        isNot(contains("<script")),
      );
    });

    test("strips event handler attributes", () {
      expect(
        sanitizePersonalDictionaryHtml("<img src=x onerror=alert(2)>"),
        "<img src=x>",
      );
      expect(
        sanitizePersonalDictionaryHtml(
          "<p onclick=\"alert(3)\" title=\"keep\">text</p>",
        ),
        "<p title=\"keep\">text</p>",
      );
    });

    test("strips dangerous URL schemes and keeps safe links", () {
      expect(
        sanitizePersonalDictionaryHtml("<a href=\"javascript:alert(3)\">x</a>"),
        "<a>x</a>",
      );
      expect(
        sanitizePersonalDictionaryHtml("<a href=\"JaVaScRiPt:alert(3)\">x</a>"),
        "<a>x</a>",
      );
      expect(
        sanitizePersonalDictionaryHtml(
          "<a href=\"javascript&#58;alert(3)\">x</a>",
        ),
        "<a>x</a>",
      );
      expect(
        sanitizePersonalDictionaryHtml(
          "<a href=\"data:text/html,<script>alert(4)</script>\">x</a>",
        ),
        isNot(contains("data:")),
      );
      expect(
        sanitizePersonalDictionaryHtml("<a href=\"https://example.com\">x</a>"),
        "<a href=\"https://example.com\">x</a>",
      );
      expect(
        sanitizePersonalDictionaryHtml("<b>bold</b> and <em>italic</em>"),
        "<b>bold</b> and <em>italic</em>",
      );
    });

    test("drops iframe/style/object content and dangerous styles", () {
      expect(
        sanitizePersonalDictionaryHtml(
          "<iframe src=\"https://example.com\"></iframe>safe",
        ),
        "safe",
      );
      expect(
        sanitizePersonalDictionaryHtml("<span style=\"color:red\">keep</span>"),
        "<span style=\"color:red\">keep</span>",
      );
      expect(
        sanitizePersonalDictionaryHtml(
          "<span style=\"xss:expression(alert(1))\">drop</span>",
        ),
        "<span>drop</span>",
      );
    });
  });

  test(
    "readExactEntries sanitizes script, event handlers and javascript: links",
    () async {
      final id = await service.createDictionary("Unsafe");
      await service.createEntry(
        id,
        headwords: ["scripted"],
        body: "<script>alert(1)</script>safe text",
      );
      await service.createEntry(
        id,
        headwords: ["imaged"],
        body: "<img src=x onerror=alert(2)>",
      );
      await service.createEntry(
        id,
        headwords: ["linked"],
        body: "[x](javascript:alert(3))",
      );
      final dict = PersonalDictionary(path: "personal:$id", database: database);
      await dict.init();

      final entries = await dict.readExactEntries([
        "scripted",
        "imaged",
        "linked",
      ]);

      expect(entries.map((e) => e.headword), ["scripted", "imaged", "linked"]);
      for (final entry in entries) {
        expect(entry.content, isNot(contains("<script")));
        expect(entry.content, isNot(contains("onerror")));
        expect(entry.content, isNot(contains("javascript:")));
        expect(entry.content, isNot(contains("alert(")));
      }
      expect(entries.first.content, contains("safe text"));
      await dict.close();
    },
  );

  test("close during init does not leak a server", () async {
    final dict = dictionary();
    final initializing = dict.init();
    // Attach immediately: the init is expected to fail, and a failure
    // with no listener yet would be reported as an unhandled async error
    // while the test waits.
    final initError = initializing.then<Object?>(
      (_) => null,
      onError: (Object error) => error,
    );
    await dict.close(waitForLoading: false);
    await Future<void>.delayed(const Duration(milliseconds: 800));

    expect(dict.port, 0);
    await dict.close();
    expect(dict.port, 0);
    expect(dict.isReady, isFalse);
    expect(await initError, isA<StateError>());
  });

  test("close then init binds a fresh server", () async {
    final dict = dictionary();
    await dict.init();

    expect(dict.port, isNot(0));
    expect(dict.isReady, isTrue);

    await dict.close();
    expect(dict.port, 0);
    expect(dict.isReady, isFalse);

    await dict.init();
    expect(dict.port, isNot(0));
    expect(dict.isReady, isTrue);

    await dict.close();
    expect(dict.port, 0);
  });

  test(
    "a failed server bind surfaces initializationError and isReady false",
    () async {
      final dict = dictionary();
      dict.bindServerForTest = (_, _) async =>
          throw const SocketException("bind failed");

      await expectLater(dict.init(), throwsA(isA<SocketException>()));

      expect(dict.initializationError, isA<SocketException>());
      expect(dict.isReady, isFalse);
      expect(dict.port, 0);
      await dict.close();
    },
  );

  test("concurrent init of two dictionaries binds distinct ports and both "
      "close cleanly (P2-34)", () async {
    final first = dictionary();
    final secondId = await service.createDictionary("Second");
    final second = PersonalDictionary(
      path: "personal:$secondId",
      database: database,
    );

    await Future.wait([first.init(), second.init()]);

    // Two dictionaries share nothing but the database: each binds its
    // own loopback server on a system-assigned port.
    expect(first.port, isNot(0));
    expect(second.port, isNot(0));
    expect(first.port, isNot(second.port));

    await Future.wait([first.close(), second.close()]);

    expect(first.port, 0);
    expect(second.port, 0);
    expect(first.isReady, isFalse);
    expect(second.isReady, isFalse);

    // A second init/close round stays safe too.
    await Future.wait([first.init(), second.init()]);
    expect(first.port, isNot(0));
    expect(second.port, isNot(0));
    expect(first.port, isNot(second.port));
    await Future.wait([first.close(), second.close()]);
    expect(first.port, 0);
    expect(second.port, 0);
  });

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

    test("a failed personal dictionary load keeps its list row", () async {
      final listDao = DictionaryListDao(mainDatabase);
      final groupDao = DictGroupDao(mainDatabase);
      // A list row whose sentinel id has no row of its own: initMetadata
      // throws, which used to delete this row and orphan its articles.
      final ghostId = await listDao.add(
        "personal:999999",
        "Ghost",
        type: DictionaryType.personal,
      );
      final groupId = await groupDao.addGroup(
        "P1-3 probe ${DateTime.now().millisecondsSinceEpoch}",
        [ghostId],
      );
      final previousGroup = dictManager.groupId;
      addTearDown(() async {
        try {
          await dictManager.setCurrentGroup(previousGroup);
        } catch (_) {}
        try {
          await groupDao.removeGroup(groupId);
        } catch (_) {}
        try {
          await listDao.removeById(ghostId);
        } catch (_) {}
      });

      await dictManager.setCurrentGroup(groupId);

      expect(await listDao.getById(ghostId), isNotNull);
      expect(dictManager.dicts.containsKey(ghostId), isFalse);
      expect(dictManager.dictIds, contains(ghostId));
    });
  });
}

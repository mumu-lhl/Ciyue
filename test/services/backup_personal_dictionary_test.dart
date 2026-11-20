import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/backup/backup.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/personal_dictionary.dart";
import "package:ciyue/services/backup.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:drift/drift.dart" show driftRuntimeOptions;
import "package:drift/native.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/mockito.dart";

import "backup_test.mocks.dart";

class _CapturingBackupFileHandler implements BackupFileHandler {
  String? exported;
  String? toImport;

  @override
  bool get isAndroid => false;

  @override
  Future<void> writeAutoExportAndroid(
    String directory,
    String fileName,
    String content,
  ) async {
    exported = content;
  }

  @override
  Future<void> writeAutoExportDesktop(String path, String content) async {
    exported = content;
  }

  @override
  Future<void> writeManualExportAndroid(String content) async {
    exported = content;
  }

  @override
  Future<void> writeManualExportDesktop(String content) async {
    exported = content;
  }

  @override
  Future<String?> readImportFile() async => toImport;
}

BackupService _serviceFor(AppDatabase db, _CapturingBackupFileHandler handler) {
  // The wordbook/history tables are irrelevant here, and their real DAOs
  // touch globals (`prefs`) that tests never initialize; stub them with
  // the mocks generated for backup_test.dart. Only the personal
  // dictionary DAOs are real.
  final wordbookDao = MockWordbookDao();
  final wordbookTagsDao = MockWordbookTagsDao();
  final historyDao = MockHistoryDao();
  final writingCheckHistoryDao = MockWritingCheckHistoryDao();
  final translateHistoryDao = MockTranslateHistoryDao();
  when(wordbookDao.getAllWords()).thenAnswer((_) async => <WordbookData>[]);
  when(wordbookTagsDao.getAllTags()).thenAnswer((_) async => <WordbookTag>[]);
  when(historyDao.getAllHistory()).thenAnswer((_) async => <HistoryData>[]);
  when(writingCheckHistoryDao.getAllHistory())
      .thenAnswer((_) async => <WritingCheckHistoryData>[]);
  when(translateHistoryDao.getAllHistory())
      .thenAnswer((_) async => <TranslateHistoryData>[]);
  when(wordbookTagsDao.addAllTags(any)).thenAnswer((_) async {});
  when(historyDao.addAllHistory(any)).thenAnswer((_) async {});
  when(writingCheckHistoryDao.addAllHistory(any)).thenAnswer((_) async {});
  when(translateHistoryDao.addAllHistory(any)).thenAnswer((_) async {});
  return BackupService(
    wordbookDao: wordbookDao,
    wordbookTagsDao: wordbookTagsDao,
    historyDao: historyDao,
    writingCheckHistoryDao: writingCheckHistoryDao,
    translateHistoryDao: translateHistoryDao,
    fileHandler: handler,
    personalDictionaryDao: PersonalDictionaryDao(db),
    dictionaryListDao: DictionaryListDao(db),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // mainDatabase is lazily opened through path_provider; without this
  // mock the DictManager test below fails with MissingPluginException.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel("plugins.flutter.io/path_provider"),
        (call) async => Directory.systemTemp.path,
      );

  group("BackupService personal dictionaries", () {
    late AppDatabase sourceDb;
    late PersonalDictionaryService sourceService;
    late int sourceId;
    late _CapturingBackupFileHandler handler;
    late String exportedJson;

    setUp(() async {
      sourceDb = AppDatabase(NativeDatabase.memory());
      sourceService = PersonalDictionaryService(sourceDb);
      sourceId = await sourceService.createDictionary("My Words");
      await sourceService.createEntry(
        sourceId,
        headwords: ["Apple", "apple fruit"],
        body: "A **red** fruit.",
      );
      await sourceService.createEntry(
        sourceId,
        headwords: ["banana"],
        body: "A *yellow* fruit.",
      );
      await sourceService.createDictionary("Empty Dict");
      handler = _CapturingBackupFileHandler();
      await _serviceFor(
        sourceDb,
        handler,
      ).export(autoExport: false, exportFileName: "test");
      exportedJson = handler.exported!;
    });

    tearDown(() => sourceDb.close());

    test("export JSON contains personal dictionary names and headwords", () {
      final decoded = jsonDecode(exportedJson) as Map<String, dynamic>;
      final dictionaries = decoded["personalDictionaries"] as List<dynamic>;
      expect(dictionaries.length, 2);
      final mine = dictionaries.firstWhere(
        (e) => (e as Map<String, dynamic>)["title"] == "My Words",
      ) as Map<String, dynamic>;
      final articles = mine["articles"] as List<dynamic>;
      expect(articles.length, 2);
      final bodies = articles
          .map((e) => (e as Map<String, dynamic>)["body"] as String)
          .toList();
      expect(bodies, contains("A **red** fruit."));
      final headwords = articles
          .expand(
            (e) => ((e as Map<String, dynamic>)["headwords"] as List<dynamic>)
                .cast<String>(),
          )
          .toList();
      expect(headwords, containsAll(["Apple", "apple fruit", "banana"]));
      final empty = dictionaries.firstWhere(
        (e) => (e as Map<String, dynamic>)["title"] == "Empty Dict",
      ) as Map<String, dynamic>;
      expect(empty["articles"], isEmpty);
    });

    test("import restores dictionaries with fresh ids", () async {
      final targetDb = AppDatabase(NativeDatabase.memory());
      addTearDown(() => targetDb.close());
      // Occupy id 1 in the target so the restored dictionary cannot
      // reuse the exported ids: import must remap them.
      final targetService = PersonalDictionaryService(targetDb);
      await targetService.createDictionary("Occupier");
      final targetHandler = _CapturingBackupFileHandler()
        ..toImport = exportedJson;

      await _serviceFor(targetDb, targetHandler).import();

      final rows = await DictionaryListDao(targetDb).all();
      final restored = rows.where(
        (row) => row.type == DictionaryType.personal && row.title == "My Words",
      );
      expect(restored.length, 1);
      final restoredId = restored.single.id;
      expect(restoredId, isNot(1));
      final entries = await targetService.listEntries(restoredId);
      expect(entries.length, 2);
      final apple = entries.firstWhere(
        (entry) => entry.headwords.contains("Apple"),
      );
      expect(apple.headwords, contains("apple fruit"));
      expect(apple.body, "A **red** fruit.");
      final emptyRows = rows.where(
        (row) =>
            row.type == DictionaryType.personal && row.title == "Empty Dict",
      );
      expect(emptyRows.length, 1);
      expect(await targetService.listEntries(emptyRows.single.id), isEmpty);

      // The restored dictionary is searchable through the repository.
      final dict = PersonalDictionary(
        path: "personal:$restoredId",
        database: targetDb,
      );
      await dict.init();
      expect(await dict.search("app"), ["Apple", "apple fruit"]);
      final read = await dict.readExactEntries(["APPLE"]);
      expect(read.single.content, contains("<strong>red</strong>"));
      await dict.close();
    });

    test("an old backup without personal dictionaries parses to empty", () {
      final imported = BackupData.fromJson({
        "version": 1,
        "wordbookWords": <Object>[],
        "wordbookTags": <Object>[],
      });

      expect(imported.personalDictionaries, isEmpty);
    });
  });

  group("BackupService personal dictionaries in DictManager", () {
    test("an imported dictionary loads through the manager", () async {
      final title = "Managed Restore ${DateTime.now().millisecondsSinceEpoch}";
      final handler = _CapturingBackupFileHandler()
        ..toImport = jsonEncode({
          "version": 1,
          "wordbookWords": <Object>[],
          "wordbookTags": <Object>[],
          "history": <String>[],
          "writingCheckHistory": <Object>[],
          "translateHistory": <Object>[],
          "personalDictionaries": [
            {
              "title": title,
              "articles": [
                {
                  "headwords": ["kiwi"],
                  "body": "A **green** fruit.",
                },
              ],
            },
          ],
        });
      final globalService = PersonalDictionaryService(mainDatabase);
      final listDao = DictionaryListDao(mainDatabase);
      final groupDao = DictGroupDao(mainDatabase);
      final groupId = await groupDao.addGroup(
        "backup restore probe ${DateTime.now().millisecondsSinceEpoch}",
        [],
      );
      final previousGroup = dictManager.groupId;
      dictManager.groupId = groupId;
      int? restoredId;
      addTearDown(() async {
        if (restoredId != null) {
          await dictManager.close(restoredId);
          try {
            final ids = await groupDao.getDictIds(groupId);
            ids.remove(restoredId);
            await groupDao.updateDictIds(groupId, ids);
          } catch (_) {}
          try {
            await globalService.deleteDictionary(restoredId!);
          } catch (_) {}
        }
        dictManager.groupId = previousGroup;
        try {
          await groupDao.removeGroup(groupId);
        } catch (_) {}
      });

      await _serviceFor(mainDatabase, handler).import();

      final rows = await listDao.all();
      final restored = rows.where(
        (row) => row.type == DictionaryType.personal && row.title == title,
      );
      expect(restored.length, 1);
      restoredId = restored.single.id;

      // The new-dictionary dialog's wiring: load it into the manager and
      // write the id back to the current group.
      await dictManager.add(restoredId, "personal:$restoredId");
      dictManager.dictIds = [...dictManager.dictIds, restoredId];
      await groupDao.updateDictIds(groupId, dictManager.dictIds);

      expect(await groupDao.getDictIds(groupId), contains(restoredId));
      final dict = dictManager.dicts[restoredId];
      expect(dict, isA<PersonalDictionary>());
      expect(dict!.title, title);
      await dict.waitForLoading();
      expect(dict.isReady, isTrue);
      expect(dict.port, isNot(0));
      expect(await dict.search("kiw"), ["kiwi"]);
      final entries = await dict.readExactEntries(["KIWI"]);
      expect(entries.single.content, contains("<strong>green</strong>"));
    });
  });
}

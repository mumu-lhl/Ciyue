import "dart:io";

import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/services/storage_usage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

Future<void> _writeFile(String path, int bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(List.filled(bytes, 0));
}

void main() {
  late Directory tempRoot;
  late Directory cacheDir;
  late Directory supportDir;
  late Directory documentsDir;
  late Directory databaseDir;
  late Directory dictionariesDir;

  StorageUsageService service({
    String? dictionariesPath,
    Future<List<PersonalDictionaryStorageEstimate>> Function()?
    personalDictionaryEstimates,
  }) {
    return StorageUsageService(
      cacheDirectory: () async => cacheDir,
      supportDirectory: () async => supportDir,
      documentsDirectory: () async => documentsDir,
      databaseDir: () async => databaseDir,
      dictionariesDirectoryPath: () async =>
          dictionariesPath ?? dictionariesDir.path,
      personalDictionaryEstimates: personalDictionaryEstimates,
    );
  }

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp("storage_usage_test");
    cacheDir = Directory(p.join(tempRoot.path, "cache"));
    supportDir = Directory(p.join(tempRoot.path, "support"));
    documentsDir = Directory(p.join(tempRoot.path, "documents"));
    databaseDir = Directory(p.join(tempRoot.path, "database"));
    dictionariesDir = Directory(p.join(tempRoot.path, "dictionaries"));
    for (final dir in [
      cacheDir,
      supportDir,
      documentsDir,
      databaseDir,
      dictionariesDir,
    ]) {
      await dir.create(recursive: true);
    }
    await _writeFile(p.join(cacheDir.path, "full_text_search.db"), 100);
    await _writeFile(p.join(cacheDir.path, "full_text_search.db-wal"), 10);
    await _writeFile(p.join(cacheDir.path, "full_text_search.db-shm"), 5);
    await _writeFile(p.join(cacheDir.path, "dict_reader_1_mdx.cidx"), 200);
    await _writeFile(p.join(cacheDir.path, "dict_reader_2_stardict.cidx"), 50);
    await _writeFile(
      p.join(cacheDir.path, "online_pronunciation", "a.mp3"),
      1000,
    );
    await _writeFile(p.join(cacheDir.path, "some_other.bin"), 40);
    await _writeFile(p.join(cacheDir.path, "webview_data", "x"), 60);
    await _writeFile(p.join(supportDir.path, "audios", "pack.mp3"), 500);
    await _writeFile(p.join(documentsDir.path, "chat_images", "img.jpg"), 80);
    // Main database: sqlite + wal (no shm file on disk).
    await _writeFile(p.join(databaseDir.path, "dictionary_list.sqlite"), 700);
    await _writeFile(
      p.join(databaseDir.path, "dictionary_list.sqlite-wal"),
      30,
    );
    await _writeFile(p.join(dictionariesDir.path, "dict.mdx"), 300);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  int bytesOf(List<StorageUsage> usages, StorageCategoryKind kind) =>
      usages.firstWhere((u) => u.kind == kind).bytes!;

  group("formatBytes", () {
    test("uses B/KB/MB/GB with one decimal", () {
      expect(formatBytes(512), "512 B");
      expect(formatBytes(1536), "1.5 KB");
      expect(formatBytes(2 * 1024 * 1024), "2.0 MB");
      expect(formatBytes(3 * 1024 * 1024 * 1024), "3.0 GB");
    });
  });

  group("measure", () {
    test("sums each category without double counting", () async {
      final usages = await service().measure();
      expect(usages.map((u) => u.kind), [
        StorageCategoryKind.dictionaries,
        StorageCategoryKind.fullTextIndex,
        StorageCategoryKind.dictionaryIndexCache,
        StorageCategoryKind.pronunciationCache,
        StorageCategoryKind.otherCache,
        StorageCategoryKind.database,
        StorageCategoryKind.audioPacks,
        StorageCategoryKind.chatImages,
      ]);
      expect(bytesOf(usages, StorageCategoryKind.dictionaries), 300);
      expect(bytesOf(usages, StorageCategoryKind.fullTextIndex), 115);
      expect(bytesOf(usages, StorageCategoryKind.dictionaryIndexCache), 250);
      expect(bytesOf(usages, StorageCategoryKind.pronunciationCache), 1000);
      expect(bytesOf(usages, StorageCategoryKind.otherCache), 100);
      expect(bytesOf(usages, StorageCategoryKind.database), 730);
      expect(bytesOf(usages, StorageCategoryKind.audioPacks), 500);
      expect(bytesOf(usages, StorageCategoryKind.chatImages), 80);
    });

    test("marks only the caches clearable", () async {
      final usages = await service().measure();
      final clearable = {
        for (final u in usages)
          if (u.clearable) u.kind,
      };
      expect(clearable, {
        StorageCategoryKind.fullTextIndex,
        StorageCategoryKind.dictionaryIndexCache,
        StorageCategoryKind.pronunciationCache,
        StorageCategoryKind.otherCache,
      });
    });

    test("reports null for dictionaries behind a content:// URI", () async {
      final usages = await service(
        dictionariesPath: "content://com.android.externalstorage.documents",
      ).measure();
      final dictionaries = usages.firstWhere(
        (u) => u.kind == StorageCategoryKind.dictionaries,
      );
      expect(dictionaries.bytes, isNull);
    });

    test("a missing documents directory counts chat images as empty, "
        "not an error", () async {
      // Regression (found in a real Linux window): on systems without a
      // documents folder, getApplicationDocumentsDirectory() throws
      // MissingPlatformDirectoryException, and the whole page showed the
      // error state with a Retry button that could never succeed.
      final noDocuments = StorageUsageService(
        cacheDirectory: () async => cacheDir,
        supportDirectory: () async => supportDir,
        documentsDirectory: () async => throw MissingPlatformDirectoryException(
          "Unable to get application documents directory",
        ),
        databaseDir: () async => databaseDir,
        dictionariesDirectoryPath: () async => dictionariesDir.path,
      );
      final usages = await noDocuments.measure();
      final byKind = {for (final u in usages) u.kind: u};
      expect(byKind[StorageCategoryKind.chatImages]!.bytes, 0);
      expect(byKind[StorageCategoryKind.fullTextIndex]!.bytes, 115);
      expect(byKind[StorageCategoryKind.dictionaries]!.bytes, 300);
    });

    test("reports 0 for missing directories", () async {
      final empty = StorageUsageService(
        cacheDirectory: () async =>
            Directory(p.join(tempRoot.path, "no-cache")),
        supportDirectory: () async =>
            Directory(p.join(tempRoot.path, "no-support")),
        documentsDirectory: () async =>
            Directory(p.join(tempRoot.path, "no-documents")),
        databaseDir: () async =>
            Directory(p.join(tempRoot.path, "no-database")),
        dictionariesDirectoryPath: () async =>
            p.join(tempRoot.path, "no-dictionaries"),
      );
      final usages = await empty.measure();
      for (final usage in usages) {
        expect(usage.bytes, 0, reason: "${usage.kind} should be 0");
      }
    });
  });

  group("clear", () {
    test("clearDictionaryIndexCache deletes only the .cidx files", () async {
      final s = service();
      expect(await s.clearDictionaryIndexCache(), 250);
      expect(
        await File(p.join(cacheDir.path, "dict_reader_1_mdx.cidx")).exists(),
        isFalse,
      );
      final usages = await s.measure();
      expect(bytesOf(usages, StorageCategoryKind.dictionaryIndexCache), 0);
      expect(bytesOf(usages, StorageCategoryKind.fullTextIndex), 115);
      expect(bytesOf(usages, StorageCategoryKind.pronunciationCache), 1000);
      expect(bytesOf(usages, StorageCategoryKind.otherCache), 100);
    });

    test("clearPronunciationCache deletes the audio directory", () async {
      final s = service();
      expect(await s.clearPronunciationCache(), 1000);
      expect(
        await Directory(p.join(cacheDir.path, "online_pronunciation")).exists(),
        isFalse,
      );
      final usages = await s.measure();
      expect(bytesOf(usages, StorageCategoryKind.pronunciationCache), 0);
      expect(bytesOf(usages, StorageCategoryKind.otherCache), 100);
    });

    test("clearOtherCache keeps the categorized cache files", () async {
      final s = service();
      expect(await s.clearOtherCache(), 100);
      expect(
        await File(p.join(cacheDir.path, "some_other.bin")).exists(),
        isFalse,
      );
      expect(
        await Directory(p.join(cacheDir.path, "webview_data")).exists(),
        isFalse,
      );
      final usages = await s.measure();
      expect(bytesOf(usages, StorageCategoryKind.otherCache), 0);
      expect(bytesOf(usages, StorageCategoryKind.fullTextIndex), 115);
      expect(bytesOf(usages, StorageCategoryKind.dictionaryIndexCache), 250);
      expect(bytesOf(usages, StorageCategoryKind.pronunciationCache), 1000);
    });

    test("clearing an already empty cache frees 0 bytes", () async {
      final s = service();
      await s.clearDictionaryIndexCache();
      await s.clearPronunciationCache();
      await s.clearOtherCache();
      expect(await s.clearDictionaryIndexCache(), 0);
      expect(await s.clearPronunciationCache(), 0);
      expect(await s.clearOtherCache(), 0);
    });
  });

  group("estimatePersonalDictionaryBytes", () {
    PersonalEntry entry(int id, List<String> headwords, String body) =>
        PersonalEntry(
          articleId: id,
          dictionaryId: 1,
          headwords: headwords,
          body: body,
          updatedAt: DateTime(2026, 11, 18),
        );

    test("sums body and headword bytes as UTF-8", () {
      expect(
        estimatePersonalDictionaryBytes([
          entry(1, ["apple"], "A fruit."),
          entry(2, ["苹果", "apple"], "一种水果。"),
        ]),
        // "A fruit." (8) + "apple" (5) + "一种水果。" (5 × 3 bytes = 15)
        // + "苹果" (2 × 3 = 6) + "apple" (5) = 39.
        39,
      );
      expect(estimatePersonalDictionaryBytes(const []), 0);
      expect(estimatePersonalDictionaryBytes([entry(3, const [], "")]), 0);
    });
  });

  group("measurePersonalDictionaries", () {
    test("returns the loader's estimates", () async {
      const estimates = [
        PersonalDictionaryStorageEstimate(
          dictionaryId: 7,
          title: "My words",
          entryCount: 3,
          estimatedBytes: 1234,
        ),
      ];
      final withLoader = service(
        personalDictionaryEstimates: () async => estimates,
      );
      expect(await withLoader.measurePersonalDictionaries(), estimates);
    });

    test("returns empty without a loader or when the loader fails", () async {
      expect(await service().measurePersonalDictionaries(), isEmpty);
      final failing = service(
        personalDictionaryEstimates: () =>
            throw StateError("database unavailable"),
      );
      expect(await failing.measurePersonalDictionaries(), isEmpty);
    });
  });
}

import "dart:async";
import "dart:io";

import "package:ciyue/services/storage_usage.dart";
import "package:ciyue/viewModels/storage_usage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late Directory tempRoot;
  late Directory cache;
  late Directory support;
  late Directory documents;
  late Directory database;
  late Directory dictionaries;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp("storage_usage_vm_test");
    cache = Directory(p.join(tempRoot.path, "cache"))..createSync();
    support = Directory(p.join(tempRoot.path, "support"))..createSync();
    documents = Directory(p.join(tempRoot.path, "documents"))..createSync();
    database = Directory(p.join(tempRoot.path, "database"))..createSync();
    dictionaries = Directory(p.join(tempRoot.path, "dictionaries"))
      ..createSync();
  });

  tearDown(() async {
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  Future<void> writeSizedFile(String path, int size) async {
    await File(path).writeAsBytes(List.filled(size, 0));
  }

  Future<StorageUsageViewModel> buildMeasuredViewModel({
    void Function()? onFullTextCall,
  }) async {
    await writeSizedFile(p.join(cache.path, "full_text_search.db"), 2048);
    await writeSizedFile(p.join(cache.path, "dict_reader_1.cidx"), 1024);
    final pronunciation = Directory(p.join(cache.path, "online_pronunciation"))
      ..createSync();
    await writeSizedFile(p.join(pronunciation.path, "a.mp3"), 512);
    await writeSizedFile(p.join(cache.path, "foo.tmp"), 256);
    final viewModel = StorageUsageViewModel(
      service: StorageUsageService(
        cacheDirectory: () async => cache,
        supportDirectory: () async => support,
        documentsDirectory: () async => documents,
        databaseDir: () async => database,
        dictionariesDirectoryPath: () async => dictionaries.path,
      ),
      onClearFullTextIndex: () async {
        onFullTextCall?.call();
        final file = File(p.join(cache.path, "full_text_search.db"));
        if (await file.exists()) await file.delete();
      },
    );
    await viewModel.refresh();
    return viewModel;
  }

  test("selection defaults to every clearable category with bytes", () async {
    final viewModel = await buildMeasuredViewModel();

    for (final kind in [
      StorageCategoryKind.fullTextIndex,
      StorageCategoryKind.dictionaryIndexCache,
      StorageCategoryKind.pronunciationCache,
      StorageCategoryKind.otherCache,
    ]) {
      expect(viewModel.isSelected(kind), isTrue);
    }
    for (final kind in [
      StorageCategoryKind.dictionaries,
      StorageCategoryKind.database,
      StorageCategoryKind.audioPacks,
      StorageCategoryKind.chatImages,
    ]) {
      expect(viewModel.isSelected(kind), isFalse);
    }
    expect(viewModel.selectedClearableBytes, 3840);
  });

  test("toggling a category excludes it from the clear only", () async {
    var fullTextCalls = 0;
    final viewModel = await buildMeasuredViewModel(
      onFullTextCall: () => fullTextCalls++,
    );

    viewModel.toggleSelection(StorageCategoryKind.fullTextIndex);
    expect(viewModel.isSelected(StorageCategoryKind.fullTextIndex), isFalse);
    expect(viewModel.selectedClearableBytes, 1792);

    await viewModel.clearSelectedCache();

    expect(fullTextCalls, 0);
    expect(
      await File(p.join(cache.path, "full_text_search.db")).exists(),
      isTrue,
    );
    expect(
      await File(p.join(cache.path, "dict_reader_1.cidx")).exists(),
      isFalse,
    );
    expect(
      await Directory(p.join(cache.path, "online_pronunciation")).exists(),
      isFalse,
    );
    expect(await File(p.join(cache.path, "foo.tmp")).exists(), isFalse);

    // Toggling again re-selects the category.
    viewModel.toggleSelection(StorageCategoryKind.fullTextIndex);
    expect(viewModel.isSelected(StorageCategoryKind.fullTextIndex), isTrue);
  });

  test("toggling a size-only category is a no-op", () async {
    final viewModel = await buildMeasuredViewModel();

    viewModel.toggleSelection(StorageCategoryKind.dictionaries);
    viewModel.toggleSelection(StorageCategoryKind.database);
    expect(viewModel.isSelected(StorageCategoryKind.dictionaries), isFalse);
    expect(viewModel.selectedClearableBytes, 3840);
  });

  test("clearSelectedCache with everything selected clears all", () async {
    var fullTextCalls = 0;
    final viewModel = await buildMeasuredViewModel(
      onFullTextCall: () => fullTextCalls++,
    );

    await viewModel.clearSelectedCache();

    expect(fullTextCalls, 1);
    expect(viewModel.selectedClearableBytes, 0);
    expect(
      await File(p.join(cache.path, "full_text_search.db")).exists(),
      isFalse,
    );
    expect(
      await File(p.join(cache.path, "dict_reader_1.cidx")).exists(),
      isFalse,
    );
  });

  test("a refresh in flight when disposed does not notify listeners", () async {
    // Regression: refresh() called notifyListeners() after the page had
    // popped and disposed the view model, throwing "used after being
    // disposed" as an unhandled async error.
    final cacheGate = Completer<Directory>();
    final service = StorageUsageService(
      cacheDirectory: () => cacheGate.future,
      supportDirectory: () async => support,
      documentsDirectory: () async => documents,
      databaseDir: () async => database,
      dictionariesDirectoryPath: () async => dictionaries.path,
    );
    final viewModel = StorageUsageViewModel(service: service);
    // The constructor's refresh is already waiting on the gate.
    viewModel.dispose();
    cacheGate.complete(cache);
    // Let the measurement finish: if refresh still notified after
    // dispose, the unhandled error fails this test.
    await Future.delayed(const Duration(seconds: 1));
  });
}

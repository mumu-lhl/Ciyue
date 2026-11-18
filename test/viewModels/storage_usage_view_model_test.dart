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

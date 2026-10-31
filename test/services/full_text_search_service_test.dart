import "dart:io";

import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/full_text_index_builder.dart";
import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search_service.dart";
import "package:flutter_test/flutter_test.dart";

class FakeDictionary implements LoadedDictionary {
  @override
  final int id;
  @override
  final int type;
  @override
  final String path;

  FakeDictionary({required this.id, required this.type, required this.path});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory dir;
  late File mdxFile;
  late FakeDictionary dictionary;
  late int buildCalls;
  late List<FullTextIndexRow> cannedRows;
  late bool pauseForCancel;
  late FullTextSearchService service;

  Future<void> fakeRunner(
    FullTextBuildRequest request, {
    required Future<void> Function(List<FullTextIndexRow>, int, int) onBatch,
    required Future<void> Function(int) onTotal,
    required FullTextBuildCancelToken cancelToken,
  }) async {
    buildCalls++;
    await onTotal(cannedRows.length);
    await onBatch([cannedRows.first], 1, cannedRows.length);
    if (pauseForCancel) {
      // Give the test a window to cancel before the remaining rows land.
      var waited = 0;
      while (!cancelToken.isCancelled && waited < 400) {
        await Future.delayed(const Duration(milliseconds: 5));
        waited++;
      }
      if (cancelToken.isCancelled) return;
    }
    for (final row in cannedRows.skip(1)) {
      if (cancelToken.isCancelled) return;
      await onBatch([row], row.rowid, cannedRows.length);
    }
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp("fts_service_test_");
    mdxFile = File("${dir.path}/dict.mdx");
    await mdxFile.writeAsBytes([1, 2, 3, 4]);
    dictionary = FakeDictionary(id: 1, type: 1, path: "${dir.path}/dict");
    buildCalls = 0;
    pauseForCancel = false;
    cannedRows = const [
      FullTextIndexRow(rowid: 1, headword: "apple", body: "a fruit"),
      FullTextIndexRow(rowid: 2, headword: "苹果", body: "一种水果"),
    ];
    service = FullTextSearchService(
      dictionaries: () => [dictionary],
      knownIds: () async => {1},
      databaseDirectory: () async => dir.path,
      runner: fakeRunner,
    );
    addTearDown(service.dispose);
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test("builds lazily and searches both languages", () async {
    await service.ensureBuilt(dictionary);
    expect(service.stateFor(1).status, FullTextIndexStatus.ready);
    expect(buildCalls, 1);

    final latin = await service.search("apple");
    expect(latin.map((h) => h.headword), ["apple"]);
    expect(await service.search("苹果"), hasLength(1));
    expect(await service.search("   "), isEmpty);
  });

  test("second ensure with the same fingerprint does not rebuild", () async {
    await service.ensureBuilt(dictionary);
    await service.ensureBuilt(dictionary);
    expect(buildCalls, 1);
  });

  test("changed dictionary file triggers a rebuild", () async {
    await service.ensureBuilt(dictionary);
    await mdxFile.writeAsBytes([1, 2, 3, 4, 5]);
    await service.ensureBuilt(dictionary);
    expect(buildCalls, 2);
  });

  test("a failing store open reports failed and retries", () async {
    var directoryCalls = 0;
    final flaky = FullTextSearchService(
      dictionaries: () => [dictionary],
      knownIds: () async => {1},
      databaseDirectory: () async {
        directoryCalls++;
        if (directoryCalls <= 2) {
          throw const FileSystemException("no dir");
        }
        return dir.path;
      },
      runner: fakeRunner,
    );
    addTearDown(flaky.dispose);

    // First attempt: reconcile and the store open both fail. No throw,
    // failed state for the retry button.
    await flaky.ensureBuilt(dictionary);
    expect(flaky.stateFor(1).status, FullTextIndexStatus.failed);

    // Second attempt retries the open and builds normally.
    await flaky.ensureBuilt(dictionary);
    expect(flaky.stateFor(1).status, FullTextIndexStatus.ready);
    expect(await flaky.search("apple"), hasLength(1));
  });

  test("cancel keeps the partial index and the next build resumes", () async {
    pauseForCancel = true;
    final building = service.ensureBuilt(dictionary);
    // Wait until the build is actually running before cancelling: the
    // token only exists once the store is open and the fingerprint read.
    var waited = 0;
    while (service.stateFor(1).status != FullTextIndexStatus.building &&
        waited < 200) {
      await Future.delayed(const Duration(milliseconds: 5));
      waited++;
    }
    expect(service.stateFor(1).status, FullTextIndexStatus.building);
    service.cancelBuild(1);
    await building;
    // Only the first row landed, and the state reports a resumable
    // partial build.
    expect(service.stateFor(1).status, FullTextIndexStatus.notBuilt);
    expect(service.stateFor(1).indexed, 1);

    pauseForCancel = false;
    await service.ensureBuilt(dictionary);
    expect(service.stateFor(1).status, FullTextIndexStatus.ready);
    expect(await service.search("苹果"), hasLength(1));
  });

  test("rebuildDictionary rebuilds from scratch", () async {
    await service.ensureBuilt(dictionary);
    expect(buildCalls, 1);
    await service.rebuildDictionary(dictionary);
    expect(buildCalls, 2);
    expect(service.stateFor(1).status, FullTextIndexStatus.ready);
    expect(await service.search("苹果"), hasLength(1));
  });

  test("rebuildDictionary cancels an in-flight build first", () async {
    pauseForCancel = true;
    service.ensureBuilt(dictionary);
    var waited = 0;
    while (service.stateFor(1).status != FullTextIndexStatus.building &&
        waited < 200) {
      await Future.delayed(const Duration(milliseconds: 5));
      waited++;
    }
    expect(service.stateFor(1).status, FullTextIndexStatus.building);
    pauseForCancel = false;
    await service.rebuildDictionary(dictionary);
    expect(buildCalls, 2);
    expect(service.stateFor(1).status, FullTextIndexStatus.ready);
    expect(await service.search("苹果"), hasLength(1));
  });

  test("dropDictionary removes the index", () async {
    await service.ensureBuilt(dictionary);
    await service.dropDictionary(1);
    expect(await service.search("apple"), isEmpty);
    expect(service.stateFor(1).status, FullTextIndexStatus.notBuilt);
  });

  test("search skips dictionaries without a ready index", () async {
    expect(await service.search("apple"), isEmpty);
  });
}

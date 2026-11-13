import "dart:io";

import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/full_text_index_builder.dart";
import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search_service.dart";
import "package:drift/drift.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

/// Minimal drift handle for seeding raw FTS tables the store itself would
/// never create — a v1-shaped index, for the stale-index rebuild test.
class _RawFtsDatabase extends GeneratedDatabase {
  _RawFtsDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  List<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
}

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
      // Long on purpose: the window must outlive the test's polling for
      // the building state (two concurrent builds in the
      // cancelBuildsExcept test), not just one.
      var waited = 0;
      while (!cancelToken.isCancelled && waited < 1200) {
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

  test(
    "stale v1 ready index is rebuilt, not served (issue #824 review)",
    () async {
      cannedRows = const [
        FullTextIndexRow(rowid: 1, headword: "社会主义", body: "一种社会制度"),
        FullTextIndexRow(rowid: 2, headword: "主义者", body: "信奉某种主义的人"),
        FullTextIndexRow(rowid: 3, headword: "参加者", body: "参与的人"),
      ];
      // Seed a v1-shaped index: two-column tables (no `headword_rev`) and
      // a pre-version fingerprint ("size:mtime", no `v2:` prefix), stamped
      // ready — the shape a multi-group user carries in a group that was
      // not current when the schema changed.
      final file = File("${dir.path}/full_text_search.db");
      final raw = _RawFtsDatabase(NativeDatabase(file));
      await raw.customStatement(
        "CREATE TABLE fts_content_1 ("
        "rowid INTEGER PRIMARY KEY, "
        "headword TEXT NOT NULL, "
        "body TEXT NOT NULL)",
      );
      await raw.customStatement(
        "CREATE VIRTUAL TABLE fts_1 USING fts5("
        "headword, body, "
        "content='fts_content_1', content_rowid='rowid', "
        "tokenize='unicode61')",
      );
      await raw.customStatement(
        "CREATE TABLE fts_meta ("
        "dictionary_id INTEGER PRIMARY KEY, "
        "fingerprint TEXT NOT NULL, "
        "total INTEGER NOT NULL DEFAULT 0, "
        "indexed INTEGER NOT NULL DEFAULT 0, "
        "state TEXT NOT NULL DEFAULT 'building', "
        "updated_at INTEGER NOT NULL)",
      );
      await raw.customStatement(
        "INSERT INTO fts_content_1 (rowid, headword, body) "
        "VALUES (1, '社会主义', '一种社会制度')",
      );
      await raw.customStatement(
        "INSERT INTO fts_1 (rowid, headword, body) "
        "VALUES (1, '社会 主义', '一 种 社会 制度')",
      );
      await raw.customStatement(
        "INSERT INTO fts_meta "
        "(dictionary_id, fingerprint, total, indexed, state, updated_at) "
        "VALUES (1, '4:1234567890', 1, 1, 'ready', 1234567890)",
      );
      await raw.close();

      // Reconcile no longer trusts the stale ready stamp: the fingerprint
      // differs, so the index reports notBuilt until it is rebuilt.
      expect(await service.indexStatus(), FullTextIndexStatus.notBuilt);

      await service.ensureBuilt(dictionary);
      expect(buildCalls, 1);
      expect(service.stateFor(1).status, FullTextIndexStatus.ready);

      // The rebuilt tables carry the v2 shape and fingerprint, and suffix
      // search — which throws on the v1 tables — works again.
      final check = _RawFtsDatabase(NativeDatabase(file));
      final meta = await check
          .customSelect(
            "SELECT fingerprint FROM fts_meta WHERE dictionary_id = 1",
          )
          .getSingle();
      expect(
        meta.read<String>("fingerprint"),
        startsWith("v$fullTextIndexSchemaVersion:"),
      );
      final create = await check
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE name = 'fts_content_1'",
          )
          .getSingle();
      expect(create.read<String>("sql"), contains("headword_rev"));
      await check.close();

      expect((await service.searchSuffix("主义")).map((h) => h.headword), [
        "社会主义",
      ]);
      expect(
        (await service.searchSuffix("者")).map((h) => h.headword),
        containsAll(["主义者", "参加者"]),
      );
    },
  );

  test("fingerprint carries the FTS schema version", () async {
    final fingerprint = await FullTextSearchService.fingerprintFor(
      1,
      "${dir.path}/dict",
    );
    // A stored fingerprint from before the version stamp ("size:mtime")
    // differs, so existing users' indexes rebuild for the new columns
    // instead of serving stale tables to the suffix query.
    expect(fingerprint, startsWith("v$fullTextIndexSchemaVersion:"));
    expect(
      await FullTextSearchService.fingerprintFor(1, "${dir.path}/missing"),
      "",
    );
  });

  test("suffix and multi-word search use the index", () async {
    cannedRows = const [
      FullTextIndexRow(rowid: 1, headword: "中国", body: "中国是一个国家"),
      FullTextIndexRow(rowid: 2, headword: "中华民国", body: "历史上的国家"),
      FullTextIndexRow(rowid: 3, headword: "中华人民共和国", body: "成立于1949年"),
      FullTextIndexRow(rowid: 4, headword: "主义者", body: "信奉某种主义的人"),
      FullTextIndexRow(rowid: 5, headword: "社会主义", body: "一种社会制度"),
      FullTextIndexRow(rowid: 6, headword: "apple", body: "中国是一种水果"),
    ];
    await service.ensureBuilt(dictionary);

    expect((await service.searchSuffix("主义")).map((h) => h.headword), ["社会主义"]);
    expect(
      (await service.searchHeadwordAnd("中国")).map((h) => h.headword),
      containsAll(["中国", "中华民国", "中华人民共和国"]),
    );
    expect(
      (await service.searchHeadwordAnd("中国")).map((h) => h.headword),
      isNot(contains("apple")),
    );
    // A mode that needs the index reports its status instead of failing
    // silently when nothing is ready.
    expect(await service.indexStatus(), FullTextIndexStatus.ready);
  });

  test("indexStatus reports an unbuilt index", () async {
    expect(await service.indexStatus(), FullTextIndexStatus.notBuilt);
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
    // Wall-time wait, as in the tests below: opening the store is slow
    // under full-suite load.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (service.stateFor(1).status != FullTextIndexStatus.building &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 5));
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
    // Same wall-time wait as the cancelBuildsExcept test below: opening
    // the store is slow under full-suite load.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (service.stateFor(1).status != FullTextIndexStatus.building &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 5));
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

  test("cancelBuildsExcept cancels only the builds outside the keep "
      "set", () async {
    final dir2 = await Directory.systemTemp.createTemp("fts_service_two_");
    final mdx2 = File("${dir2.path}/dict.mdx");
    await mdx2.writeAsBytes([1, 2, 3, 4]);
    final dictionary2 = FakeDictionary(
      id: 2,
      type: 1,
      path: "${dir2.path}/dict",
    );
    addTearDown(() => dir2.delete(recursive: true));
    final two = FullTextSearchService(
      dictionaries: () => [dictionary, dictionary2],
      knownIds: () async => {1, 2},
      databaseDirectory: () async => dir.path,
      runner: fakeRunner,
    );
    addTearDown(two.dispose);

    // Both builds pause after their first batch; only dictionary 2 leaves
    // the group.
    pauseForCancel = true;
    final build1 = two.ensureBuilt(dictionary);
    final build2 = two.ensureBuilt(dictionary2);
    // Opening the store (background-isolate spawn, WAL setup, reconcile,
    // FTS table creation) is slow under full-suite load — over 400 5 ms
    // polls in the 2026-11-13 gate — so wait on wall time, not on a fixed
    // number of polls. The runner's pause window is not consumed by this
    // wait: build 2's runner only starts pausing once build 2 reaches
    // `building`, and the cancel below lands right after.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while ((two.stateFor(1).status != FullTextIndexStatus.building ||
            two.stateFor(2).status != FullTextIndexStatus.building) &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 5));
    }
    expect(two.stateFor(1).status, FullTextIndexStatus.building);
    expect(two.stateFor(2).status, FullTextIndexStatus.building);
    expect(two.stateFor(1).status, FullTextIndexStatus.building);
    expect(two.stateFor(2).status, FullTextIndexStatus.building);

    two.cancelBuildsExcept({1});
    pauseForCancel = false;
    await Future.wait([build1, build2]);

    expect(two.stateFor(1).status, FullTextIndexStatus.ready);
    // Only the first row landed before the cancel; the partial index
    // stays resumable.
    expect(two.stateFor(2).status, FullTextIndexStatus.notBuilt);
    expect(two.stateFor(2).indexed, 1);
  });

  test("search merges hits from several dictionaries", () async {
    final dir2 = await Directory.systemTemp.createTemp("fts_service_merge_");
    final mdx2 = File("${dir2.path}/dict.mdx");
    await mdx2.writeAsBytes([1, 2, 3, 4]);
    final dictionary2 = FakeDictionary(
      id: 2,
      type: 1,
      path: "${dir2.path}/dict",
    );
    addTearDown(() => dir2.delete(recursive: true));
    final two = FullTextSearchService(
      dictionaries: () => [dictionary, dictionary2],
      knownIds: () async => {1, 2},
      databaseDirectory: () async => dir.path,
      runner: fakeRunner,
    );
    addTearDown(two.dispose);

    await two.ensureBuilt(dictionary);
    await two.ensureBuilt(dictionary2);
    expect(two.stateFor(1).status, FullTextIndexStatus.ready);
    expect(two.stateFor(2).status, FullTextIndexStatus.ready);

    // The same headword from both dictionaries, merged by rank.
    final hits = await two.search("apple");
    expect(hits.map((h) => h.dictionaryId).toSet(), {1, 2});
    expect(hits.map((h) => h.headword).toSet(), {"apple"});
  });

  test("a newer search supersedes an in-flight one", () async {
    await service.ensureBuilt(dictionary);

    // Issued back to back: the first search has not even left its first
    // await when the second one bumps the generation, so its hits are
    // stale by the time the background queries return.
    final first = service.search("apple");
    final second = service.search("苹果");
    expect(await first, isEmpty);
    expect((await second).map((h) => h.headword), ["苹果"]);
  });
}

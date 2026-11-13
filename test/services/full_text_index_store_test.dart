import "dart:io";

import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search.dart";
import "package:drift/drift.dart" hide isNull;
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

/// Minimal drift handle for talking to a store file directly (pragma
/// reads), mirroring the service test's raw database.
class _RawDb extends GeneratedDatabase {
  _RawDb(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  List<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
}

void main() {
  late FullTextIndexStore store;

  setUp(() {
    store = FullTextIndexStore(NativeDatabase.memory());
  });

  tearDown(() async {
    await store.close();
  });

  test("indexes and finds English and Chinese content", () async {
    expect(await store.ensureDictionary(1, "fp1"), isTrue);
    await store.insertBatch(1, const [
      FullTextIndexRow(
        rowid: 1,
        headword: "apple",
        body: "a round fruit that grows on trees",
      ),
      FullTextIndexRow(rowid: 2, headword: "苹果", body: "苹果是一种水果"),
    ], 2);
    await store.markComplete(1, 2);

    final latin = await store.searchOne(1, '"apple"');
    expect(latin.map((h) => h.headword), ["apple"]);

    final cjk = await store.searchOne(1, '"苹 果"');
    expect(cjk.map((h) => h.headword), ["苹果"]);
    expect(
      parseSnippet(cjk.single.snippet).where((s) => s.isMatch).isNotEmpty,
      isTrue,
    );
  });

  test("headword matches rank before body matches", () async {
    expect(await store.ensureDictionary(2, "fp"), isTrue);
    await store.insertBatch(2, const [
      FullTextIndexRow(rowid: 1, headword: "pie", body: "apple filling"),
      FullTextIndexRow(rowid: 2, headword: "apple", body: "a fruit for pies"),
    ], 2);
    await store.markComplete(2, 2);

    final hits = await store.searchOne(2, '"apple"');
    expect(hits.map((h) => h.headword), ["apple", "pie"]);
  });

  test("same fingerprint and ready state skips rebuild", () async {
    expect(await store.ensureDictionary(3, "fp"), isTrue);
    await store.insertBatch(3, const [
      FullTextIndexRow(rowid: 1, headword: "a", body: "b"),
    ], 1);
    await store.markComplete(3, 1);
    expect(await store.ensureDictionary(3, "fp"), isFalse);

    // A changed fingerprint rebuilds from scratch.
    expect(await store.ensureDictionary(3, "fp2"), isTrue);
    expect((await store.meta(3))!.indexed, 0);
    expect(await store.searchOne(3, '"a"'), isEmpty);
  });

  test("markComplete keeps the stored indexed count", () async {
    expect(await store.ensureDictionary(7, "fp"), isTrue);
    await store.insertBatch(7, const [
      FullTextIndexRow(rowid: 1, headword: "a", body: "b"),
    ], 1);
    // 4 dictionary entries, one indexed (the rest had empty bodies).
    await store.markComplete(7, 4);
    final meta = (await store.meta(7))!;
    expect(meta.indexed, 1);
    expect(meta.total, 4);
    expect(meta.state, FullTextIndexDbState.ready);
  });

  test("cancelled build resumes from stored progress", () async {
    expect(await store.ensureDictionary(4, "fp"), isTrue);
    await store.insertBatch(4, const [
      FullTextIndexRow(rowid: 1, headword: "a", body: "b"),
    ], 1);
    // State stays 'building': the next ensure keeps the partial tables.
    expect(await store.ensureDictionary(4, "fp"), isTrue);
    expect((await store.meta(4))!.indexed, 1);
    expect((await store.searchOne(4, '"a"')).map((h) => h.headword), ["a"]);
  });

  group("suffix and multi-word search (issue #824)", () {
    // One shared index: Latin, Chinese and Japanese headwords, plus the
    // traps — headwords that contain the query without ending in it, and
    // a body that mentions the query without the headword doing so.
    const rows = [
      FullTextIndexRow(rowid: 1, headword: "running", body: "moving fast"),
      FullTextIndexRow(rowid: 2, headword: "walking", body: "moving on foot"),
      FullTextIndexRow(rowid: 3, headword: "king-size", body: "a bed size"),
      FullTextIndexRow(
        rowid: 4,
        headword: "reading-room",
        body: "a quiet room",
      ),
      FullTextIndexRow(rowid: 5, headword: "马克思主义", body: "一种理论"),
      FullTextIndexRow(rowid: 6, headword: "主义者", body: "信奉某种主义的人"),
      FullTextIndexRow(rowid: 7, headword: "社会主义", body: "一种社会制度"),
      FullTextIndexRow(rowid: 8, headword: "中国", body: "中国是一个国家"),
      FullTextIndexRow(rowid: 9, headword: "中华民国", body: "历史上的国家"),
      FullTextIndexRow(rowid: 10, headword: "中华人民共和国", body: "成立于1949年"),
      FullTextIndexRow(rowid: 11, headword: "中华", body: "中华民族"),
      FullTextIndexRow(rowid: 12, headword: "美国", body: "美利坚合众国"),
      FullTextIndexRow(rowid: 13, headword: "apple", body: "中国是一种水果"),
      FullTextIndexRow(rowid: 14, headword: "運動", body: "体を動かすこと"),
      FullTextIndexRow(rowid: 15, headword: "行動", body: "行動すること"),
      FullTextIndexRow(rowid: 16, headword: "動詞", body: "品詞の一つ"),
      FullTextIndexRow(rowid: 17, headword: "読者", body: "本を読む人"),
      FullTextIndexRow(rowid: 18, headword: "作者", body: "本を書く人"),
      FullTextIndexRow(rowid: 19, headword: "test者", body: "a test person"),
      FullTextIndexRow(rowid: 20, headword: "者test", body: "ends otherwise"),
      FullTextIndexRow(rowid: 21, headword: "pick up", body: "to lift"),
      FullTextIndexRow(rowid: 22, headword: "pick", body: "to choose"),
    ];

    Future<void> buildIndex() async {
      expect(await store.ensureDictionary(10, "fp"), isTrue);
      await store.insertBatch(10, rows, rows.length);
      await store.markComplete(10, rows.length);
    }

    test("suffix matches headwords ending with the query", () async {
      await buildIndex();
      expect(
        (await store.searchSuffixOne(10, "ing")).map((h) => h.headword),
        containsAll(["running", "walking"]),
      );
      // "king-size" and "reading-room" contain "ing" in a reversed token
      // but do not end with it: the endsWith post-filter drops them.
      expect(
        (await store.searchSuffixOne(10, "ing")).map((h) => h.headword),
        isNot(contains("king-size")),
      );
      expect(
        (await store.searchSuffixOne(10, "ing")).map((h) => h.headword),
        isNot(contains("reading-room")),
      );
    });

    test("suffix CJK matches are anchored at the end", () async {
      await buildIndex();
      expect(
        (await store.searchSuffixOne(10, "主义")).map((h) => h.headword),
        containsAll(["马克思主义", "社会主义"]),
      );
      // 主义者 merely contains 主义: the FTS phrase matches, the
      // endsWith filter must not let it through.
      expect(
        (await store.searchSuffixOne(10, "主义")).map((h) => h.headword),
        isNot(contains("主义者")),
      );
    });

    test("suffix Japanese matches are anchored at the end", () async {
      await buildIndex();
      expect(
        (await store.searchSuffixOne(10, "動")).map((h) => h.headword),
        containsAll(["運動", "行動"]),
      );
      expect(
        (await store.searchSuffixOne(10, "動")).map((h) => h.headword),
        isNot(contains("動詞")),
      );
      expect(
        (await store.searchSuffixOne(10, "者")).map((h) => h.headword),
        containsAll(["読者", "作者", "test者"]),
      );
      expect(
        (await store.searchSuffixOne(10, "者")).map((h) => h.headword),
        isNot(contains("者test")),
      );
    });

    test("suffix mixed-script queries keep the Latin tail anchored", () async {
      await buildIndex();
      expect(
        (await store.searchSuffixOne(10, "test者")).map((h) => h.headword),
        ["test者"],
      );
      expect(
        (await store.searchSuffixOne(10, "者test")).map((h) => h.headword),
        ["者test"],
      );
    });

    test("suffix recall survives many containing-but-not-ending headwords "
        "(issue #824 review)", () async {
      // The review's probe: 60 two-character "者X" decoys that contain
      // the query without ending in it, plus 3 true endings. Before
      // the SQL pushdown the LIMIT applied before the endsWith filter,
      // the short decoys filled all 50 pre-filter slots, and the
      // query came back empty.
      final rows = [
        for (var i = 0; i < 60; i++)
          FullTextIndexRow(
            rowid: i + 1,
            headword: "者${String.fromCharCode(0x4E00 + i)}",
            body: "decoy",
          ),
        const FullTextIndexRow(
          rowid: 61,
          headword: "参加者",
          body: "a participant",
        ),
        const FullTextIndexRow(
          rowid: 62,
          headword: "责任者",
          body: "a responsible person",
        ),
        const FullTextIndexRow(
          rowid: 63,
          headword: "test者",
          body: "a test person",
        ),
      ];
      expect(await store.ensureDictionary(11, "fp"), isTrue);
      await store.insertBatch(11, rows, rows.length);
      await store.markComplete(11, rows.length);

      expect(
        (await store.searchSuffixOne(11, "者")).map((h) => h.headword),
        containsAll(["参加者", "责任者", "test者"]),
      );
    });

    test("multi-word AND matches non-adjacent headword characters", () async {
      await buildIndex();
      // The acceptance example: the old phrase builder ("中 国",
      // adjacency required) misses both of these.
      expect(
        (await store.searchHeadwordAndOne(10, "中国")).map((h) => h.headword),
        containsAll(["中国", "中华民国", "中华人民共和国"]),
      );
      expect(
        (await store.searchHeadwordAndOne(10, "中国")).map((h) => h.headword),
        isNot(contains("中华")),
      );
      expect(
        (await store.searchHeadwordAndOne(10, "中国")).map((h) => h.headword),
        isNot(contains("美国")),
      );
      // "apple" mentions 中国 in its body only: the headword-column
      // qualification must keep it out.
      expect(
        (await store.searchHeadwordAndOne(10, "中国")).map((h) => h.headword),
        isNot(contains("apple")),
      );
    });

    test("multi-word AND works for Latin words", () async {
      await buildIndex();
      expect(
        (await store.searchHeadwordAndOne(
          10,
          "pick up",
        )).map((h) => h.headword),
        ["pick up"],
      );
    });
  });

  test("dropDictionary removes tables and meta", () async {
    expect(await store.ensureDictionary(5, "fp"), isTrue);
    await store.insertBatch(5, const [
      FullTextIndexRow(rowid: 1, headword: "a", body: "b"),
    ], 1);
    await store.markComplete(5, 1);
    await store.dropDictionary(5);
    expect(await store.meta(5), isNull);
    expect(await store.allMeta(), isEmpty);
  });

  test("indexSizeBytes reports the built index and 0 after drop", () async {
    expect(await store.indexSizeBytes(8), 0);
    expect(await store.ensureDictionary(8, "fp"), isTrue);
    await store.insertBatch(8, const [
      FullTextIndexRow(rowid: 1, headword: "apple", body: "a fruit"),
    ], 1);
    await store.markComplete(8, 1);
    expect(await store.indexSizeBytes(8), greaterThan(0));
    await store.dropDictionary(8);
    expect(await store.indexSizeBytes(8), 0);
  });

  test("pruneExcept drops orphaned dictionaries", () async {
    await store.ensureDictionary(6, "fp");
    await store.ensureDictionary(7, "fp");
    await store.pruneExcept({6});
    expect((await store.allMeta()).map((m) => m.dictionaryId), [6]);
  });

  group("background isolate store (Slice B)", () {
    test("openFile uses WAL and auto_vacuum=FULL", () async {
      final dir = await Directory.systemTemp.createTemp("fts_store_open_");
      try {
        final fileStore = await FullTextIndexStore.openFile(
          File("${dir.path}/fts.db"),
        );
        try {
          // A second connection to the same file reads the persisted
          // pragmas: WAL (readers run while a build writes) and FULL
          // (drops free their pages).
          final check = _RawDb(NativeDatabase(File("${dir.path}/fts.db")));
          final journal = await check
              .customSelect("PRAGMA journal_mode")
              .getSingle();
          expect(journal.read<String>("journal_mode"), "wal");
          final vacuum = await check
              .customSelect("PRAGMA auto_vacuum")
              .getSingle();
          expect(vacuum.read<int>("auto_vacuum"), 1);
          await check.close();
        } finally {
          await fileStore.close();
        }
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test("multi-value insert matches row-by-row results", () async {
      // One dictionary written as a single batch, one written one row at
      // a time: the FTS5 content tables and shadow tables must agree, so
      // the same queries return the same hits in the same order.
      const rows = [
        FullTextIndexRow(rowid: 1, headword: "running", body: "moving fast"),
        FullTextIndexRow(rowid: 2, headword: "walking", body: "moving on foot"),
        FullTextIndexRow(rowid: 3, headword: "king-size", body: "a bed size"),
        FullTextIndexRow(rowid: 4, headword: "社会主义", body: "一种社会制度"),
        FullTextIndexRow(rowid: 5, headword: "主义者", body: "信奉某种主义的人"),
        FullTextIndexRow(rowid: 6, headword: "中国", body: "中国是一个国家"),
        FullTextIndexRow(rowid: 7, headword: "中华民国", body: "历史上的国家"),
        FullTextIndexRow(rowid: 8, headword: "中华人民共和国", body: "成立于1949年"),
        FullTextIndexRow(rowid: 9, headword: "apple", body: "中国是一种水果"),
      ];
      expect(await store.ensureDictionary(20, "fp"), isTrue);
      await store.insertBatch(20, rows, rows.length);
      await store.markComplete(20, rows.length);

      expect(await store.ensureDictionary(21, "fp"), isTrue);
      for (final row in rows) {
        await store.insertBatch(21, [row], row.rowid);
      }
      await store.markComplete(21, rows.length);

      String dump(List<FullTextHit> hits) =>
          hits.map((h) => "${h.headword}|${h.rank}|${h.snippet}").join("\n");
      for (final query in ['"apple"', '"苹 果"', '"中国"']) {
        expect(
          dump(await store.searchOne(21, query)),
          dump(await store.searchOne(20, query)),
        );
      }
      expect(
        dump(await store.searchSuffixOne(21, "主义")),
        dump(await store.searchSuffixOne(20, "主义")),
      );
      expect(
        dump(await store.searchSuffixOne(21, "ing")),
        dump(await store.searchSuffixOne(20, "ing")),
      );
      expect(
        dump(await store.searchHeadwordAndOne(21, "中国")),
        dump(await store.searchHeadwordAndOne(20, "中国")),
      );
      // A re-inserted row keeps its content_rowid: the resumed build
      // re-sends stored rows with INSERT OR REPLACE. The re-insert
      // changes bm25 ranks (pre-existing FTS5 REPLACE behaviour —
      // a single-row re-insert perturbs the rank identically, probe
      // 2026-11-13), so compare headwords and snippets, not ranks.
      await store.insertBatch(20, rows.sublist(0, 3), 3);
      String hitsOnly(List<FullTextHit> hits) =>
          hits.map((h) => "${h.headword}|${h.snippet}").join("\n");
      expect(
        hitsOnly(await store.searchOne(20, '"apple"')),
        hitsOnly(await store.searchOne(21, '"apple"')),
      );
    });

    test("pre-tokenized rows index the same as raw rows", () async {
      // The builder isolate ships rows with the derived columns already
      // computed; the store must use them as-is and produce the same
      // index as tokenizing the raw rows itself.
      final tokenized = [
        FullTextIndexRow(
          rowid: 1,
          headword: "apple",
          body: "a round fruit",
          headwordRev: reverseHeadword("apple"),
          headwordTokenized: tokenizeForIndex("apple"),
          headwordRevTokenized: tokenizeForIndex(reverseHeadword("apple")),
          bodyTokenized: tokenizeForIndex("a round fruit"),
        ),
        FullTextIndexRow(
          rowid: 2,
          headword: "苹果",
          body: "苹果是一种水果",
          headwordRev: reverseHeadword("苹果"),
          headwordTokenized: tokenizeForIndex("苹果"),
          headwordRevTokenized: tokenizeForIndex(reverseHeadword("苹果")),
          bodyTokenized: tokenizeForIndex("苹果是一种水果"),
        ),
        FullTextIndexRow(
          rowid: 3,
          headword: "running",
          body: "moving fast",
          headwordRev: reverseHeadword("running"),
          headwordTokenized: tokenizeForIndex("running"),
          headwordRevTokenized: tokenizeForIndex(reverseHeadword("running")),
          bodyTokenized: tokenizeForIndex("moving fast"),
        ),
      ];
      final raw = [
        for (final row in tokenized)
          FullTextIndexRow(
            rowid: row.rowid,
            headword: row.headword,
            body: row.body,
          ),
      ];
      expect(await store.ensureDictionary(22, "fp"), isTrue);
      await store.insertBatch(22, tokenized, tokenized.length);
      await store.markComplete(22, tokenized.length);
      expect(await store.ensureDictionary(23, "fp"), isTrue);
      await store.insertBatch(23, raw, raw.length);
      await store.markComplete(23, raw.length);

      String dump(List<FullTextHit> hits) =>
          hits.map((h) => "${h.headword}|${h.rank}|${h.snippet}").join("\n");
      expect(
        dump(await store.searchOne(22, '"apple"')),
        dump(await store.searchOne(23, '"apple"')),
      );
      expect(
        dump(await store.searchOne(22, '"苹 果"')),
        dump(await store.searchOne(23, '"苹 果"')),
      );
      expect(
        dump(await store.searchSuffixOne(22, "ing")),
        dump(await store.searchSuffixOne(23, "ing")),
      );
      expect(
        dump(await store.searchHeadwordAndOne(22, "苹果")),
        dump(await store.searchHeadwordAndOne(23, "苹果")),
      );
    });

    test("dropDictionary reclaims space and records auto_vacuum on a "
        "pre-existing database", () async {
      final dir = await Directory.systemTemp.createTemp("fts_store_drop_");
      try {
        final file = File("${dir.path}/full_text_search.db");
        // A database from before the flag: created without the setup, so
        // auto_vacuum is NONE and the open-time set is ignored until a
        // VACUUM records it.
        final legacy = _RawDb(NativeDatabase(file));
        await legacy.customStatement("CREATE TABLE legacy (x TEXT)");
        await legacy.customStatement("INSERT INTO legacy VALUES ('seed')");
        await legacy.close();

        final fileStore = await FullTextIndexStore.openFile(file);
        try {
          expect(await fileStore.ensureDictionary(1, "fp"), isTrue);
          final rows = [
            for (var i = 1; i <= 500; i++)
              FullTextIndexRow(
                rowid: i,
                headword: "word$i",
                body:
                    "entry $i about the history of the apple "
                    "and the world at large, with the quick brown "
                    "fox and the lazy dog running through the "
                    "fields of the valley",
              ),
          ];
          await fileStore.insertBatch(1, rows, rows.length);
          await fileStore.markComplete(1, rows.length);
          expect((await fileStore.searchOne(1, '"apple"')), isNotEmpty);
          // In WAL mode the fresh pages live in the -wal file until a
          // checkpoint, so the on-disk size of the fresh index is the main
          // file plus -wal.
          final wal = File("${file.path}-wal");
          final built =
              await file.length() +
              (await wal.exists() ? await wal.length() : 0);
          expect(built, greaterThan(100000));

          await fileStore.dropDictionary(1);
          expect(await fileStore.meta(1), isNull);
        } finally {
          await fileStore.close();
        }
        // The DROP freed its pages and the VACUUM recorded the flag, so
        // the file shrank and later drops free their pages immediately.
        expect(await file.length(), lessThan(100000));
        final check = _RawDb(NativeDatabase(file));
        final vacuum = await check
            .customSelect("PRAGMA auto_vacuum")
            .getSingle();
        expect(vacuum.read<int>("auto_vacuum"), 1);
        await check.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test("concurrent searches across dictionaries run in parallel on "
        "the read pool", () async {
      final dir = await Directory.systemTemp.createTemp("fts_store_pool_");
      try {
        final fileStore = await FullTextIndexStore.openFile(
          File("${dir.path}/fts.db"),
        );
        try {
          final rows = [
            for (var i = 1; i <= 20000; i++)
              FullTextIndexRow(
                rowid: i,
                headword: "word$i",
                body:
                    "entry $i about the history of the apple "
                    "and the world",
              ),
          ];
          for (final id in [1, 2, 3]) {
            expect(await fileStore.ensureDictionary(id, "fp$id"), isTrue);
            await fileStore.insertBatch(id, rows, rows.length);
            await fileStore.markComplete(id, rows.length);
          }
          Future<int> timed(int id) async {
            final stopwatch = Stopwatch()..start();
            await fileStore.searchOne(id, '"the"');
            return stopwatch.elapsedMilliseconds;
          }

          // Warm the reader connections before timing.
          await fileStore.searchOne(1, '"the"');
          final t1 = await timed(1);
          final t2 = await timed(2);
          final t3 = await timed(3);
          final stopwatch = Stopwatch()..start();
          await Future.wait([timed(1), timed(2), timed(3)]);
          final wall = stopwatch.elapsedMilliseconds;
          // Three queries on three reader isolates finish in about one
          // query's time, not three; the 0.8 bound leaves room for a
          // loaded machine while still failing on a serialized pool.
          expect(wall, lessThan((t1 + t2 + t3) * 0.8));
        } finally {
          await fileStore.close();
        }
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}

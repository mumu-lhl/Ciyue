import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

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
}

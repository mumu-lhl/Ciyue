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

  test("pruneExcept drops orphaned dictionaries", () async {
    await store.ensureDictionary(6, "fp");
    await store.ensureDictionary(7, "fp");
    await store.pruneExcept({6});
    expect((await store.allMeta()).map((m) => m.dictionaryId), [6]);
  });
}

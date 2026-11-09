import "dart:io";

import "package:ciyue/models/hunspell.dart";
import "package:ciyue/services/hunspell.dart";
import "package:test/test.dart";

void main() {
  test("loads enabled Hunspell sources and returns stems", () async {
    final manager = HunspellManager();
    addTearDown(manager.close);

    await manager.reload([
      HunspellSourceInfo(
        id: 1,
        name: "simple",
        affPath: File("packages/hunspell_ffi/test/fixtures/simple.aff")
            .absolute
            .path,
        dicPath: File("packages/hunspell_ffi/test/fixtures/simple.dic")
            .absolute
            .path,
        language: null,
        enabled: true,
        order: 0,
      ),
    ]);

    expect(await manager.stems("rims"), contains("rim"));
    expect(await manager.suggestions("rimm"), contains("rim"));
    expect(manager.loadedSourceCount, 1);
  });

  test("loads Hunspell sources and returns all multiple st: stems", () async {
    final manager = HunspellManager();
    addTearDown(manager.close);

    await manager.reload([
      HunspellSourceInfo(
        id: 2,
        name: "multiple_stems",
        affPath: File("packages/hunspell_ffi/test/fixtures/multiple_stems.aff")
            .absolute
            .path,
        dicPath: File("packages/hunspell_ffi/test/fixtures/multiple_stems.dic")
            .absolute
            .path,
        language: null,
        enabled: true,
        order: 0,
      ),
    ]);

    expect(await manager.stems("たい積"), unorderedEquals(["体積", "堆積", "滞積"]));
    expect(await manager.stems("发"), unorderedEquals(["髮", "發"]));
    expect(await manager.stems("mixed"), unorderedEquals(["stem1", "stem2"]));
  });

  test("supports two-pass stem lookup per source", () async {
    final manager = HunspellManager();
    addTearDown(manager.close);

    await manager.reload([
      HunspellSourceInfo(
        id: 2,
        name: "single_pass",
        affPath: File("packages/hunspell_ffi/test/fixtures/multiple_stems.aff")
            .absolute
            .path,
        dicPath: File("packages/hunspell_ffi/test/fixtures/multiple_stems.dic")
            .absolute
            .path,
        language: null,
        enabled: true,
        order: 0,
        twoPassLookup: false,
      ),
    ]);

    expect(await manager.stems("drunkest"), equals(["drunk"]));

    await manager.reload([
      HunspellSourceInfo(
        id: 2,
        name: "two_pass",
        affPath: File("packages/hunspell_ffi/test/fixtures/multiple_stems.aff")
            .absolute
            .path,
        dicPath: File("packages/hunspell_ffi/test/fixtures/multiple_stems.dic")
            .absolute
            .path,
        language: null,
        enabled: true,
        order: 0,
        twoPassLookup: true,
      ),
    ]);

    expect(
      await manager.stems("drunkest"),
      unorderedEquals(["drunk", "drink"]),
    );
  });

  test("normalises a decomposed query before asking Hunspell", () async {
    final manager = HunspellManager();
    addTearDown(manager.close);

    await manager.reload([
      HunspellSourceInfo(
        id: 3,
        name: "nfc",
        affPath: File("packages/hunspell_ffi/test/fixtures/nfc.aff")
            .absolute
            .path,
        dicPath: File("packages/hunspell_ffi/test/fixtures/nfc.dic")
            .absolute
            .path,
        language: null,
        enabled: true,
        order: 0,
      ),
    ]);

    // The `.dic` stores the composed spelling. Hunspell compares bytes and
    // never normalises, so without the normalisation a decomposed query finds
    // nothing at all.
    // `ingle\u0301sito` is "inglésito" decomposed: `e` + U+0301, not the
    // precomposed U+00E9 the `.dic` holds.
    expect(await manager.stems("ingle\u0301sito"), equals(["ingl\u00E9s"]));
    expect(await manager.stems("ingl\u00E9sito"), equals(["ingl\u00E9s"]));
  });

  test("skips disabled sources", () async {
    final manager = HunspellManager();
    addTearDown(manager.close);

    await manager.reload([
      const HunspellSourceInfo(
        id: 1,
        name: "disabled",
        affPath: "missing.aff",
        dicPath: "missing.dic",
        language: null,
        enabled: false,
        order: 0,
      ),
    ]);

    expect(await manager.stems("rims"), isEmpty);
    expect(manager.loadedSourceCount, 0);
  });

  test("splits phrases into words and returns combined stems", () async {
    final manager = HunspellManager();
    addTearDown(manager.close);

    await manager.reload([
      HunspellSourceInfo(
        id: 1,
        name: "simple",
        affPath: File("packages/hunspell_ffi/test/fixtures/simple.aff")
            .absolute
            .path,
        dicPath: File("packages/hunspell_ffi/test/fixtures/simple.dic")
            .absolute
            .path,
        language: null,
        enabled: true,
        order: 0,
      ),
    ]);

    expect(await manager.stems("rims up"), equals(["rim up"]));
    expect(await manager.stems("  rims   up  "), equals(["rim up"]));
    expect(await manager.stems("rim up"), isEmpty);
    expect(await manager.stems("unknown phrase here"), isEmpty);
  });

  test("combines multiple stems for phrases", () async {
    final manager = HunspellManager();
    addTearDown(manager.close);

    await manager.reload([
      HunspellSourceInfo(
        id: 2,
        name: "multiple_stems",
        affPath: File("packages/hunspell_ffi/test/fixtures/multiple_stems.aff")
            .absolute
            .path,
        dicPath: File("packages/hunspell_ffi/test/fixtures/multiple_stems.dic")
            .absolute
            .path,
        language: null,
        enabled: true,
        order: 0,
        twoPassLookup: true,
      ),
    ]);

    expect(
      await manager.stems("mixed up"),
      unorderedEquals(["stem1 up", "stem2 up"]),
    );
    expect(
      await manager.stems("drunkest driver"),
      unorderedEquals(["drunk driver", "drink driver"]),
    );
  });

  test("combines the single-character variants of a CJK word", () async {
    final manager = HunspellManager();
    addTearDown(manager.close);
    await _loadCjkVariants(manager);

    // `闲 st:閒` and `闲 st:閑` link one character, not the word, so `闲适`
    // has five spellings and no `.dic` line was written for any of them.
    final stems = await manager.stems("闲适");

    expect(stems, hasLength(5));
    expect(stems, unorderedEquals(["闲適", "閒适", "閒適", "閑适", "閑適"]));
    // Closest to what was typed first: one replaced character before two.
    expect(stems.take(3), unorderedEquals(["闲適", "閒适", "閑适"]));
    expect(stems.skip(3), unorderedEquals(["閒適", "閑適"]));
  });

  test("keeps an explicit word-level link ahead of the combinations", () async {
    final manager = HunspellManager();
    addTearDown(manager.close);
    await _loadCjkVariants(manager);

    // `黄钟 st:黃鐘` is the spelling the dictionary itself links, so it is
    // tried before the character combinations the other entries generate.
    final stems = await manager.stems("黄钟");

    expect(stems.first, equals("黃鐘"));
    expect(stems, unorderedEquals(["黃鐘", "黃钟", "黄鐘"]));
  });

  test(
    "reaches the standard spelling from a query written with variants",
    () async {
      final manager = HunspellManager();
      addTearDown(manager.close);
      await _loadCjkVariants(manager);

      // What another app shares after the user selects `閒適` in it: the
      // dictionary stores `闲适`, and only the character table knows they match.
      expect(await manager.stems("閒適"), contains("闲适"));
      expect(await manager.stems("黃鐘"), contains("黄钟"));
    },
  );

  test("does not expand text without wide characters", () async {
    final manager = HunspellManager();
    addTearDown(manager.close);

    await manager.reload([
      HunspellSourceInfo(
        id: 5,
        name: "multiple_stems",
        affPath: File("packages/hunspell_ffi/test/fixtures/multiple_stems.aff")
            .absolute
            .path,
        dicPath: File("packages/hunspell_ffi/test/fixtures/multiple_stems.dic")
            .absolute
            .path,
        language: null,
        enabled: true,
        order: 0,
      ),
    ]);

    // A Latin word keeps its whole-word stems only: character expansion is for
    // scripts written without spaces.
    expect(await manager.stems("mixed"), unorderedEquals(["stem1", "stem2"]));
    // `たい積` is wide text, but none of its characters has a variant, so the
    // word-level entries are all that comes back.
    expect(await manager.stems("たい積"), unorderedEquals(["体積", "堆積", "滞積"]));
  });

  test("stops expanding a run longer than the character limit", () async {
    final manager = HunspellManager();
    addTearDown(manager.close);
    await _loadCjkVariants(manager);

    // 64 characters still expand — the bound keeps the per-character lookups
    // bounded, it does not refuse long words as such.
    expect(await manager.stems("${"木" * 62}闲适"), hasLength(5));

    // 65 characters are left alone, so a pasted paragraph costs one lookup per
    // dictionary rather than one per character. The product here is only 6, so
    // the combination bound alone would have let it through.
    expect(await manager.stems("${"木" * 63}闲适"), isEmpty);
  });
}

Future<void> _loadCjkVariants(HunspellManager manager) {
  return manager.reload([
    HunspellSourceInfo(
      id: 4,
      name: "cjk_variants",
      affPath: File("packages/hunspell_ffi/test/fixtures/cjk_variants.aff")
          .absolute
          .path,
      dicPath: File("packages/hunspell_ffi/test/fixtures/cjk_variants.dic")
          .absolute
          .path,
      language: null,
      enabled: true,
      order: 0,
    ),
  ]);
}

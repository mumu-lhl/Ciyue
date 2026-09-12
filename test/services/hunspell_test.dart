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
}

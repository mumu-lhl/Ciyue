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

import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/store.dart";
import "package:ciyue/services/store.dart";
import "package:drift/drift.dart" hide isNotNull, isNull;
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("StoreCatalogParser", () {
    test("parses dictionary, hunspell, and audio items from YAML", () {
      const yaml = """
schemaVersion: 1
items:
  - id: ecdict-mini
    type: dictionary
    name: ECDICT Mini
    description: |
      Open-source English-Chinese dictionary.
    author: skywind3000
    license: MIT
    sourceUrl: https://github.com/skywind3000/ECDICT
    languages:
      - en
      - zh
    format: mdx
    extract: true
    source:
      type: github_release
      repo: mumu-lhl/Ciyue-Store
      assetPattern: "ecdict-mini-*.zip"

  - id: hunspell-zh-cn
    type: hunspell
    name: Chinese Hunspell
    description: Chinese morphological data
    author: yx-wh
    license: GPL-3.0
    sourceUrl: https://github.com/yx-wh/hunspell_zh_CN
    languages:
      - zh
    format: hunspell
    extract: false
    source:
      type: github_raw
      repo: yx-wh/hunspell_zh_CN
      branch: main
      files:
        - zh_CN.aff
        - zh_CN.dic

  - id: en-us-audio
    type: audio
    name: US English Pronunciation
    description: Direct audio pack
    author: Community
    license: CC-BY-SA-4.0
    sourceUrl: https://example.com/audio
    languages:
      - en
    format: audio_zips
    source:
      type: direct
      url: https://example.com/en_us.zips
""";

      final warnings = <String>[];
      final catalog = StoreCatalogParser.parse(yaml, onWarning: warnings.add);

      expect(warnings, isEmpty);
      expect(catalog.schemaVersion, 1);
      expect(catalog.items, hasLength(3));

      final dict = catalog.items[0];
      expect(dict.id, "ecdict-mini");
      expect(dict.type, StoreItemType.dictionary);
      expect(dict.author, "skywind3000");
      expect(dict.license, "MIT");
      expect(dict.extract, isTrue);
      expect(dict.source.type, StoreSourceType.githubRelease);
      expect(dict.source.repo, "mumu-lhl/Ciyue-Store");
      expect(dict.source.assetPatterns, ["ecdict-mini-*.zip"]);

      final hunspell = catalog.items[1];
      expect(hunspell.type, StoreItemType.hunspell);
      expect(hunspell.extract, isFalse);
      expect(hunspell.source.type, StoreSourceType.githubRaw);
      expect(hunspell.source.branch, "main");
      expect(hunspell.source.rawFiles, ["zh_CN.aff", "zh_CN.dic"]);

      final audio = catalog.items[2];
      expect(audio.type, StoreItemType.audio);
      expect(audio.format, StoreItemFormat.audioZips);
      expect(audio.extract, isFalse);
      expect(audio.source.type, StoreSourceType.direct);
      expect(audio.source.directFiles.single.filename, "en_us.zips");
    });

    test(
      "skips invalid items missing license/sourceUrl/author and duplicates",
      () {
        const yaml = """
schemaVersion: 1
items:
  - id: missing-license
    type: dictionary
    name: Bad Dict
    author: Someone
    sourceUrl: https://example.com
    format: mdx
    source:
      type: direct
      url: https://example.com/a.mdx
  - id: dup-item
    type: hunspell
    name: Good Hunspell
    author: Author
    license: MIT
    sourceUrl: https://example.com
    format: hunspell
    source:
      type: github_raw
      repo: a/b
      files: [a.aff, a.dic]
  - id: dup-item
    type: hunspell
    name: Duplicate Hunspell
    author: Author
    license: MIT
    sourceUrl: https://example.com
    format: hunspell
    source:
      type: github_raw
      repo: a/b
      files: [a.aff, a.dic]
""";

        final warnings = <String>[];
        final catalog = StoreCatalogParser.parse(yaml, onWarning: warnings.add);

        expect(catalog.items, hasLength(1));
        expect(catalog.items.single.id, "dup-item");
        expect(catalog.items.single.name, "Good Hunspell");
        expect(warnings, hasLength(2));
      },
    );
  });

  group("applyStoreMirror", () {
    test("leaves URLs unchanged when mirror mode is none", () {
      const url =
          "https://raw.githubusercontent.com/mumu-lhl/Ciyue-Store/main/catalog.yaml";
      expect(applyStoreMirror(url, mode: StoreMirrorMode.none), url);
    });

    test("rewrites raw.githubusercontent.com to jsDelivr and leaves api.github.com untouched", () {
      const rawUrl =
          "https://raw.githubusercontent.com/yx-wh/hunspell_zh_CN/main/zh_CN.aff";
      expect(
        applyStoreMirror(rawUrl, mode: StoreMirrorMode.jsdelivr),
        "https://cdn.jsdelivr.net/gh/yx-wh/hunspell_zh_CN@main/zh_CN.aff",
      );

      const apiUrl =
          "https://api.github.com/repos/yx-wh/hunspell_zh_CN/commits";
      expect(applyStoreMirror(apiUrl, mode: StoreMirrorMode.jsdelivr), apiUrl);
    });

    test("applies custom proxy prefix to github.com and raw.githubusercontent.com only", () {
      const releaseUrl =
          "https://github.com/mumu-lhl/Ciyue-Store/releases/download/v1/a.zip";
      expect(
        applyStoreMirror(
          releaseUrl,
          mode: StoreMirrorMode.custom,
          customPrefix: "https://gh-proxy.com",
        ),
        "https://gh-proxy.com/$releaseUrl",
      );

      const apiUrl =
          "https://api.github.com/repos/mumu-lhl/Ciyue-Store/releases/latest";
      expect(
        applyStoreMirror(
          apiUrl,
          mode: StoreMirrorMode.custom,
          customPrefix: "https://gh-proxy.com/",
        ),
        apiUrl,
      );
    });
  });

  group("matchStoreAssetPattern", () {
    test("matches exact and wildcard asset names case-insensitively", () {
      expect(matchStoreAssetPattern("ecdict-v1.0.zip", "ecdict-*.zip"), isTrue);
      expect(matchStoreAssetPattern("ECDICT.ZIP", "*.zip"), isTrue);
      expect(matchStoreAssetPattern("ecdict.tar.gz", "*.zip"), isFalse);
    });
  });

  group("StoreInstalledItemDao", () {
    late AppDatabase db;
    late StoreInstalledItemDao dao;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dao = StoreInstalledItemDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      "upserts, queries, updates, and removes installed store items",
      () async {
        final now = DateTime.utc(2026, 11, 27);
        await dao.upsert(
          StoreInstalledItemsCompanion(
            itemId: const Value("hunspell-zh-cn"),
            type: const Value("hunspell"),
            format: const Value("hunspell"),
            installDir: const Value("/tmp/store/hunspell/hunspell-zh-cn"),
            remoteVersion: const Value("abc123@2026-11-01T00:00:00Z"),
            installedAt: Value(now),
            targetIds: const Value("1"),
          ),
        );

        final fetched = await dao.getById("hunspell-zh-cn");
        expect(fetched, isNotNull);
        expect(fetched!.targetIds, "1");
        expect(fetched.remoteVersion, "abc123@2026-11-01T00:00:00Z");

        await dao.upsert(
          StoreInstalledItemsCompanion(
            itemId: const Value("hunspell-zh-cn"),
            type: const Value("hunspell"),
            format: const Value("hunspell"),
            installDir: const Value("/tmp/store/hunspell/hunspell-zh-cn"),
            remoteVersion: const Value("def456@2026-11-20T00:00:00Z"),
            installedAt: Value(now),
            targetIds: const Value("1"),
          ),
        );

        final all = await dao.all();
        expect(all, hasLength(1));
        expect(all.single.remoteVersion, "def456@2026-11-20T00:00:00Z");

        await dao.remove("hunspell-zh-cn");
        expect(await dao.getById("hunspell-zh-cn"), isNull);
      },
    );
  });
}

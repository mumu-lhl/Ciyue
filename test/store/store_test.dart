import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/store.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/store.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/store/store_page.dart";
import "package:drift/drift.dart" hide isNotNull, isNull;
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

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

    test(
      "parses translations and falls back from region to language to default",
      () {
        const yaml = """
schemaVersion: 1
items:
  - id: hunspell-zh-cn
    type: hunspell
    name: 中文默认名
    description: 中文默认描述
    author: yx-wh
    license: GPL-3.0
    sourceUrl: https://example.com/zh
    languages:
      - zh
    format: hunspell
    translations:
      en:
        name: English name
        description: English description
      zh:
        name: 中文翻译名
        description: 中文翻译描述
      zh_TW:
        name: 繁體名稱
        description: 繁體描述
      ja:
        description: 日本語の説明
    source:
      type: github_raw
      repo: a/b
      files: [a.aff, a.dic]
""";

        final warnings = <String>[];
        final catalog = StoreCatalogParser.parse(yaml, onWarning: warnings.add);
        final item = catalog.items.single;

        expect(warnings, isEmpty);
        expect(item.translations, hasLength(4));
        expect(item.translations.containsKey("zh_tw"), isTrue);

        expect(item.localizedName("zh-TW"), "繁體名稱");
        expect(item.localizedDescription("zh-TW"), "繁體描述");
        expect(item.localizedName("zh-HK"), "中文翻译名");
        expect(item.localizedName("ja"), "中文默认名");
        expect(item.localizedDescription("ja"), "日本語の説明");
        expect(item.localizedName("fr"), "中文默认名");
        expect(item.localizedDescription("fr"), "中文默认描述");
        expect(item.localizedName("en-US"), "English name");

        final localized = item.localized("zh-TW");
        expect(localized.name, "繁體名稱");
        expect(localized.description, "繁體描述");
        expect(localized.id, item.id);
        expect(localized.source.type, StoreSourceType.githubRaw);
        expect(localized.translations, same(item.translations));
      },
    );

    test("keeps an item when translations are malformed", () {
      const yaml = """
schemaVersion: 1
items:
  - id: bad-translations
    type: hunspell
    name: 默认名
    description: 默认描述
    author: Tester
    license: MIT
    sourceUrl: https://example.com
    format: hunspell
    translations: not-a-map
    source:
      type: github_raw
      repo: a/b
      files: [a.aff, a.dic]
""";

      final warnings = <String>[];
      final catalog = StoreCatalogParser.parse(yaml, onWarning: warnings.add);
      final item = catalog.items.single;

      expect(item.translations, isEmpty);
      expect(item.localizedName("en"), "默认名");
      expect(item.localizedDescription("en"), "默认描述");
      expect(warnings, hasLength(1));
      expect(warnings.single, contains("translations"));
    });

    test("skips invalid translation entries and keeps valid ones", () {
      const yaml = """
schemaVersion: 1
items:
  - id: partial-translations
    type: hunspell
    name: 默认名
    description: 默认描述
    author: Tester
    license: MIT
    sourceUrl: https://example.com
    format: hunspell
    translations:
      en: not-a-map
      "":
        name: Empty key
      ja:
        name: ""
        description: ""
      zh:
        name: 有效翻译
    source:
      type: github_raw
      repo: a/b
      files: [a.aff, a.dic]
""";

      final warnings = <String>[];
      final catalog = StoreCatalogParser.parse(yaml, onWarning: warnings.add);
      final item = catalog.items.single;

      expect(item.translations, hasLength(1));
      expect(item.localizedName("zh"), "有效翻译");
      expect(item.localizedName("en"), "默认名");
      expect(warnings, hasLength(3));
      expect(warnings.any((w) => w.contains("must be a mapping")), isTrue);
      expect(warnings.any((w) => w.contains("empty locale key")), isTrue);
      expect(warnings.any((w) => w.contains("no name or description")), isTrue);
    });
  });

  group("storeDownloadExpectedLength", () {
    test("uses Content-Length when the response is not encoded", () {
      expect(storeDownloadExpectedLength(contentLength: "315"), 315);
      expect(
        storeDownloadExpectedLength(contentLength: "315", contentEncoding: ""),
        315,
      );
    });

    test("skips Content-Length when the response is encoded", () {
      expect(
        storeDownloadExpectedLength(
          contentLength: "307",
          contentEncoding: "gzip",
        ),
        isNull,
      );
    });

    test("returns null for missing or invalid Content-Length", () {
      expect(storeDownloadExpectedLength(), isNull);
      expect(
        storeDownloadExpectedLength(contentLength: "not-a-number"),
        isNull,
      );
    });
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

  group("StoreCatalogSource", () {
    test(
      "encodes and decodes custom sources while filtering invalid entries",
      () {
        const s1 = StoreCatalogSource(
          id: "custom_1",
          name: "Community",
          url: "https://example.com/a.yaml",
          enabled: true,
        );
        const s2 = StoreCatalogSource(
          id: "custom_2",
          name: "",
          url: "https://mirror.example.org/b.yaml",
          enabled: false,
        );

        final encoded = StoreCatalogSource.encodeList([s1, s2]);
        final decoded = StoreCatalogSource.decodeList(encoded);

        expect(decoded, hasLength(2));
        expect(decoded[0].id, "custom_1");
        expect(decoded[0].displayName("Official"), "Community");
        expect(decoded[1].id, "custom_2");
        expect(decoded[1].enabled, isFalse);
        expect(decoded[1].displayName("Official"), "mirror.example.org");

        final official = StoreCatalogSource.official();
        expect(official.isOfficial, isTrue);
        expect(official.displayName("Official"), "Official");
      },
    );

    test("decodeList ignores official id, empty urls, and duplicates", () {
      const raw = '''
      [
        {"id": "official", "name": "Spoof", "url": "https://a.com/1.yaml"},
        {"id": "c1", "name": "Valid", "url": "https://a.com/1.yaml"},
        {"id": "c1", "name": "Dup ID", "url": "https://a.com/2.yaml"},
        {"id": "c2", "name": "Dup URL", "url": "https://a.com/1.yaml"},
        {"id": "c3", "name": "Empty URL", "url": ""}
      ]
      ''';
      final decoded = StoreCatalogSource.decodeList(raw);
      expect(decoded, hasLength(1));
      expect(decoded.single.id, "c1");
    });
  });

  group("StoreService.fetchCatalogs", () {
    setUpAll(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await initPrefs();
      await settings.setStoreMirrorMode(StoreMirrorMode.none);
    });

    const yamlA = """
schemaVersion: 1
items:
  - id: shared-item
    type: dictionary
    name: Dict From Official
    description: Official description
    author: Author A
    license: MIT
    sourceUrl: https://example.com/a
    languages: [en]
    format: mdx
    extract: false
    source:
      type: direct
      files:
        - url: https://example.com/a.mdx
          filename: a.mdx
""";

    const yamlB = """
schemaVersion: 1
name: Community Repo
items:
  - id: shared-item
    type: dictionary
    name: Dict From Custom
    description: Custom description
    author: Author B
    license: Apache-2.0
    sourceUrl: https://example.com/b
    languages: [zh]
    format: mdx
    extract: false
    source:
      type: direct
      files:
        - url: https://example.com/b.mdx
          filename: b.mdx
""";

    test(
      "fetches multiple enabled sources and namespaces custom storageKeys",
      () async {
        final service = StoreService();
        final sources = [
          StoreCatalogSource.official(enabled: true),
          const StoreCatalogSource(
            id: "custom_1",
            name: "Custom",
            url: "https://custom.example.com/catalog.yaml",
            enabled: true,
          ),
          const StoreCatalogSource(
            id: "custom_disabled",
            name: "Disabled",
            url: "https://disabled.example.com/catalog.yaml",
            enabled: false,
          ),
        ];

        final result = await service.fetchCatalogs(
          sources: sources,
          forceRefresh: true,
          fetcher: (url) async {
            if (url == defaultStoreCatalogUrl) return yamlA;
            if (url == "https://custom.example.com/catalog.yaml") return yamlB;
            throw StateError("Disabled source should not be fetched: $url");
          },
        );

        expect(result.enabledSourceCount, 2);
        expect(result.failures, isEmpty);
        expect(result.allFailed, isFalse);
        expect(result.entries, hasLength(2));
        expect(result.entries[0].item.name, "Dict From Official");
        expect(result.entries[0].storageKey, "shared-item");
        expect(result.entries[0].displaySourceName("Official"), "Official");
        expect(result.entries[1].item.name, "Dict From Custom");
        expect(result.entries[1].storageKey, "custom_1::shared-item");
        expect(result.entries[1].catalogName, "Community Repo");
        expect(result.entries[1].displaySourceName("Official"), "Custom");

        const unnamedCustom = StoreCatalogSource(
          id: "custom_2",
          name: "",
          url: "https://custom.example.com/catalog.yaml",
          enabled: true,
        );
        final unnamedResult = await service.fetchCatalogs(
          sources: [unnamedCustom],
          forceRefresh: true,
          fetcher: (_) async => yamlB,
        );
        expect(
          unnamedResult.entries.single.displaySourceName("Official"),
          "Community Repo",
        );
      },
    );

    test("tolerates partial source failure and flags when all fail", () async {
      final service = StoreService();
      final sources = [
        StoreCatalogSource.official(enabled: true),
        const StoreCatalogSource(
          id: "custom_bad",
          name: "Broken",
          url: "https://broken.example.com/catalog.yaml",
          enabled: true,
        ),
      ];

      final partial = await service.fetchCatalogs(
        sources: sources,
        forceRefresh: true,
        fetcher: (url) async {
          if (url == defaultStoreCatalogUrl) return yamlA;
          throw Exception("Network error");
        },
      );

      expect(partial.enabledSourceCount, 2);
      expect(partial.entries, hasLength(1));
      expect(partial.failures, hasLength(1));
      expect(partial.failures.single.source.id, "custom_bad");
      expect(partial.allFailed, isFalse);

      final allFailed = await service.fetchCatalogs(
        sources: sources,
        forceRefresh: true,
        fetcher: (url) async => throw Exception("Offline"),
      );

      expect(allFailed.entries, isEmpty);
      expect(allFailed.failures, hasLength(2));
      expect(allFailed.allFailed, isTrue);

      final noneEnabled = await service.fetchCatalogs(
        sources: [StoreCatalogSource.official(enabled: false)],
        forceRefresh: true,
      );
      expect(noneEnabled.enabledSourceCount, 0);
      expect(noneEnabled.entries, isEmpty);
      expect(noneEnabled.allFailed, isFalse);
    });
  });

  group("StoreSettingsDialog", () {
    setUp(() async {
      await settings.setStoreOfficialCatalogEnabled(true);
      await settings.setStoreCustomCatalogSources(const []);
    });

    testWidgets(
      "toggles official source without delete, adds and deletes custom sources, and saves",
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: StoreSettingsDialog()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Official"), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

        // Toggle official source off
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();

        // Add a custom source
        await tester.tap(find.text("Add Source"));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, "Name (optional)"),
          "My Repo",
        );
        await tester.enterText(
          find.widgetWithText(TextField, "Catalog URL (YAML)"),
          "https://example.com/custom.yaml",
        );
        await tester.tap(find.text("Add"));
        await tester.pumpAndSettle();

        expect(find.text("My Repo"), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

        // Save
        await tester.tap(find.text("Save"));
        await tester.pumpAndSettle();

        expect(settings.storeOfficialCatalogEnabled, isFalse);
        expect(settings.storeCustomCatalogSources, hasLength(1));
        expect(settings.storeCustomCatalogSources.single.name, "My Repo");
        expect(
          settings.storeCustomCatalogSources.single.url,
          "https://example.com/custom.yaml",
        );
        expect(settings.storeCustomCatalogSources.single.enabled, isTrue);
      },
    );
  });
}

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/translation_sources.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("language mapping", () {
    test("google codes", () {
      expect(mapLang(googleLangMap, "zh"), "zh-CN");
      expect(mapLang(googleLangMap, "zh_TW"), "zh-TW");
      expect(mapLang(googleLangMap, "en"), "en");
      expect(mapLang(googleLangMap, "auto"), "auto");
    });

    test("microsoft codes", () {
      expect(mapLang(microsoftLangMap, "zh"), "zh-Hans");
      expect(mapLang(microsoftLangMap, "zh_HK"), "zh-Hant");
      expect(mapLang(microsoftLangMap, "auto"), "");
    });

    test("deepl codes", () {
      expect(deeplTargetLang("zh"), "ZH");
      expect(deeplTargetLang("zh_TW"), "ZH");
      expect(deeplTargetLang("en"), "EN-US");
      expect(deeplTargetLang("de"), "DE");
      expect(deeplSourceLang("auto"), "");
      expect(deeplSourceLang("en"), "EN");
      expect(deeplSourceLang("ja"), "JA");
    });

    test("baidu codes", () {
      expect(mapLang(baiduLangMap, "zh"), "zh");
      expect(mapLang(baiduLangMap, "zh_TW"), "cht");
      expect(mapLang(baiduLangMap, "ja"), "jp");
      expect(mapLang(baiduLangMap, "ko"), "kor");
      expect(mapLang(baiduLangMap, "fr"), "fra");
    });

    test("yandex codes", () {
      expect(mapLang(yandexLangMap, "zh"), "zh");
      expect(mapLang(yandexLangMap, "nb"), "no");
      expect(mapLang(yandexLangMap, "auto"), "");
    });

    test("deepl official codes use HANS/HANT", () {
      expect(deeplOfficialTargetLang("zh"), "ZH-HANS");
      expect(deeplOfficialTargetLang("zh_TW"), "ZH-HANT");
      expect(deeplOfficialTargetLang("zh_HK"), "ZH-HANT");
      expect(deeplOfficialTargetLang("en"), "EN-US");
      expect(deeplOfficialSourceLang("auto"), "");
      expect(deeplOfficialSourceLang("zh"), "ZH-HANS");
      expect(deeplOfficialSourceLang("zh_TW"), "ZH-HANT");
      // The Free source keeps plain ZH (with regionalVariant instead).
      expect(deeplTargetLang("zh"), "ZH");
    });

    test("tencent codes", () {
      expect(mapLang(tencentLangMap, "zh"), "zh");
      expect(mapLang(tencentLangMap, "zh_TW"), "zh");
      expect(mapLang(tencentLangMap, "zh_HK"), "zh");
      expect(mapLang(tencentLangMap, "en"), "en");
    });

    test("joinFragments keeps CJK tight and spaces Latin", () {
      expect(joinFragments(["你好", "世界"]), "你好世界");
      expect(joinFragments(["こんにちは", "世界"]), "こんにちは世界");
      expect(joinFragments(["Hello ", "world"]), "Hello  world");
      expect(joinFragments(["Hello", "world"]), "Hello world");
      expect(joinFragments(["하나", "둘"]), "하나둘");
    });

    test("normalizeDetectedLanguage maps provider codes", () {
      expect(normalizeDetectedLanguage("zh-CN"), "zh");
      expect(normalizeDetectedLanguage("zh-Hans"), "zh");
      expect(normalizeDetectedLanguage("zh-TW"), "zh_TW");
      expect(normalizeDetectedLanguage("zh-Hant"), "zh_TW");
      expect(normalizeDetectedLanguage("zh-HK"), "zh_HK");
      expect(normalizeDetectedLanguage("en-US"), "en");
      expect(normalizeDetectedLanguage("ja"), "ja");
      expect(normalizeDetectedLanguage("xx-YY"), isNull);
      expect(normalizeDetectedLanguage(null), isNull);
      expect(normalizeDetectedLanguage(""), isNull);
    });
  });

  group("TranslationSourcesConfig", () {
    setUpAll(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: {
            "translationSourceOrder",
            "translationSourcesEnabled",
            "translationProvider",
          },
        ),
      );
    });

    setUp(() async {
      await prefs.remove("translationSourceOrder");
      await prefs.remove("translationSourcesEnabled");
    });

    test("default order contains all 23 sources", () {
      final order = TranslationSourcesConfig.loadOrder();
      expect(order.length, 23);
      expect(order.first, "google");
      expect(
        order,
        containsAll([
          "ai:gemini",
          "ai:deepseek",
          "ai:anthropic",
          "ai:ollama",
          "google",
          "microsoft",
          "deeplFree",
          "baidu",
          "tencent",
          "volcengine",
          "yandexFree",
          "deeplx",
          "deepl",
          "googleCloud",
          "azure",
          "yandex",
        ]),
      );
    });

    test("default order groups free, then AI, then key sources", () {
      final order = TranslationSourcesConfig.loadOrder();
      // Free sources (zero configuration) come first, in order.
      expect(order.sublist(0, 7), [
        "google",
        "microsoft",
        "deeplFree",
        "baidu",
        "tencent",
        "volcengine",
        "yandexFree",
      ]);
      // Then the AI provider sources.
      expect(order.sublist(7, 18).every((id) => id.startsWith("ai:")), isTrue);
      // Key-based sources and DeepLX come last.
      expect(order.sublist(18), [
        "deeplx",
        "deepl",
        "googleCloud",
        "azure",
        "yandex",
      ]);
    });

    test("saved order equal to the old AI-first default migrates", () async {
      final expected = TranslationSourcesConfig.loadOrder();
      expect(expected.first, "google");
      final sources = allTranslationSources;
      final legacy = [
        for (final s in sources)
          if (s.isAi) s.id,
        for (final s in sources)
          if (!s.isAi && !s.requiresConfig) s.id,
        for (final s in sources)
          if (!s.isAi && s.requiresConfig) s.id,
      ];
      expect(legacy.first, startsWith("ai:"));
      await TranslationSourcesConfig.saveOrder(legacy);
      expect(TranslationSourcesConfig.loadOrder(), expected);
    });

    test("saved order is respected and new sources appended", () async {
      await TranslationSourcesConfig.saveOrder(["baidu", "google"]);
      final order = TranslationSourcesConfig.loadOrder();
      expect(order.first, "baidu");
      expect(order[1], "google");
      expect(order.length, 23);
    });

    test("round-trip enabled list", () async {
      await TranslationSourcesConfig.saveEnabled(["google", "baidu"]);
      expect(TranslationSourcesConfig.loadEnabled(), ["google", "baidu"]);
    });

    test("unknown ids are filtered out", () async {
      await TranslationSourcesConfig.saveEnabled(["nope", "google"]);
      expect(TranslationSourcesConfig.loadEnabled(), ["google"]);
    });

    test("saved order and enabled lists are deduped", () async {
      await TranslationSourcesConfig.saveOrder([
        "google",
        "google",
        "baidu",
        "baidu",
      ]);
      final order = TranslationSourcesConfig.loadOrder();
      expect(order.where((id) => id == "google").length, 1);
      expect(order.where((id) => id == "baidu").length, 1);
      expect(order.first, "google");

      await TranslationSourcesConfig.saveEnabled(["google", "google"]);
      expect(TranslationSourcesConfig.loadEnabled(), ["google"]);
    });
  });

  group("source registry", () {
    test("all sources have unique ids and names", () {
      final ids = allTranslationSources.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final s in allTranslationSources) {
        expect(s.name, isNotEmpty);
        expect(translationSourceById(s.id)?.id, s.id);
      }
    });

    test("free sources need no config; key sources do", () {
      for (final id in [
        "google",
        "microsoft",
        "baidu",
        "tencent",
        "volcengine",
        "yandexFree",
        "deeplFree",
      ]) {
        final s = translationSourceById(id)!;
        expect(s.requiresConfig, isFalse, reason: id);
        expect(s.isConfigured, isTrue, reason: id);
      }
      for (final id in ["deeplx", "deepl", "googleCloud", "azure", "yandex"]) {
        expect(translationSourceById(id)!.requiresConfig, isTrue, reason: id);
      }
    });

    test("each AI provider is its own source", () {
      final aiSources = allTranslationSources.where((s) => s.isAi).toList();
      expect(aiSources.length, 11);
      expect(aiSources.first.id, "ai:openai");
      expect(translationSourceById("ai:deepseek")!.name, contains("DeepSeek"));
      for (final s in aiSources) {
        expect(s.requiresConfig, isTrue, reason: s.id);
      }
      // Non-AI sources are not flagged as AI.
      expect(translationSourceById("google")!.isAi, isFalse);
    });

    test("legacy ai id migrates to the current provider source", () {
      expect(migrateSourceId("google"), "google");
      expect(migrateSourceId("ai:openai"), "ai:openai");
    });
  });
}

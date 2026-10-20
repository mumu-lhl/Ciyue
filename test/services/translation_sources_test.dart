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

    test("default order contains all 13 sources", () {
      final order = TranslationSourcesConfig.loadOrder();
      expect(order.length, 13);
      expect(order.first, "ai");
      expect(
        order,
        containsAll([
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

    test("saved order is respected and new sources appended", () async {
      await TranslationSourcesConfig.saveOrder(["baidu", "ai"]);
      final order = TranslationSourcesConfig.loadOrder();
      expect(order.first, "baidu");
      expect(order[1], "ai");
      expect(order.length, 13);
    });

    test("round-trip enabled list", () async {
      await TranslationSourcesConfig.saveEnabled(["google", "baidu"]);
      expect(TranslationSourcesConfig.loadEnabled(), ["google", "baidu"]);
    });

    test("unknown ids are filtered out", () async {
      await TranslationSourcesConfig.saveEnabled(["nope", "google"]);
      expect(TranslationSourcesConfig.loadEnabled(), ["google"]);
    });
  });

  group("source registry", () {
    test("all sources have unique ids and names", () {
      final ids = allTranslationSources.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final s in allTranslationSources) {
        expect(s.name, isNotEmpty);
        expect(translationSourceById(s.id), same(s));
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
  });
}

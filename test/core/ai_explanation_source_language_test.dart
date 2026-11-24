import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  late ProviderContainer container;
  late List<DictGroupData> originalGroups;
  late int originalGroupId;

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  setUp(() {
    originalGroups = dictManager.groups;
    originalGroupId = dictManager.groupId;
    settings.aiExplainSourceLanguageMode = "fixed";
    settings.aiExplainSourceLanguage = "auto";
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    settings.aiExplainSourceLanguageMode = "fixed";
    settings.aiExplainSourceLanguage = "auto";
    dictManager.groups = originalGroups;
    dictManager.groupId = originalGroupId;
  });

  test("defaults to auto", () {
    expect(container.read(aiExplanationSourceLanguageProvider("中国")), "auto");
  });

  test("uses the global default when set", () {
    settings.aiExplainSourceLanguage = "ja";
    expect(container.read(aiExplanationSourceLanguageProvider("中国")), "ja");
  });

  test("per-word override wins over the global default", () {
    settings.aiExplainSourceLanguage = "ja";
    container
            .read(aiExplanationSourceLanguageOverrideProvider("中国").notifier)
            .state =
        "de";

    expect(container.read(aiExplanationSourceLanguageProvider("中国")), "de");
  });

  test("an auto override falls back to the global default", () {
    settings.aiExplainSourceLanguage = "ja";
    container
            .read(aiExplanationSourceLanguageOverrideProvider("中国").notifier)
            .state =
        "auto";

    expect(container.read(aiExplanationSourceLanguageProvider("中国")), "ja");
  });

  group("group name mode", () {
    test("uses the mapped active group name", () {
      settings.aiExplainSourceLanguageMode = "groupName";
      dictManager.groups = [
        const DictGroupData(
          dictIds: "",
          hunspellIds: "",
          id: 7,
          name: "德語",
          order: 0,
        ),
      ];
      dictManager.groupId = 7;

      expect(container.read(aiExplanationSourceLanguageProvider("中国")), "de");
    });

    test("falls back to auto for the Default group", () {
      settings.aiExplainSourceLanguageMode = "groupName";
      dictManager.groups = [
        const DictGroupData(
          dictIds: "",
          hunspellIds: "",
          id: 1,
          name: "Default",
          order: 0,
        ),
      ];
      dictManager.groupId = 1;

      expect(container.read(aiExplanationSourceLanguageProvider("中国")), "auto");
    });

    test("falls back to auto for an unrecognized group name", () {
      settings.aiExplainSourceLanguageMode = "groupName";
      dictManager.groups = [
        const DictGroupData(
          dictIds: "",
          hunspellIds: "",
          id: 8,
          name: "英汉双解",
          order: 0,
        ),
      ];
      dictManager.groupId = 8;

      expect(container.read(aiExplanationSourceLanguageProvider("中国")), "auto");
    });

    test("per-word override still beats the group name", () {
      settings.aiExplainSourceLanguageMode = "groupName";
      dictManager.groups = [
        const DictGroupData(
          dictIds: "",
          hunspellIds: "",
          id: 7,
          name: "日语",
          order: 0,
        ),
      ];
      dictManager.groupId = 7;
      container
              .read(aiExplanationSourceLanguageOverrideProvider("中国").notifier)
              .state =
          "de";

      expect(container.read(aiExplanationSourceLanguageProvider("中国")), "de");
    });
  });
}

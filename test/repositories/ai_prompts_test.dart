import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("AIPrompts", () {
    setUpAll(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: {
            "customExplainPrompt",
            "customTranslatePrompt",
            "customWritingCheckPrompt",
            "customQuizPrompt",
            "customVocabularyPrompt",
            "customScenarioPrompt",
          },
        ),
      );
    });

    setUp(() async {
      for (final definition in AIPrompts.allDefinitions) {
        await prefs.remove(definition.prefsKey);
      }
    });

    test("defaults are used when nothing is stored", () {
      final prompts = AIPrompts();
      for (final definition in AIPrompts.allDefinitions) {
        expect(prompts.promptFor(definition), definition.defaultText);
        expect(prompts.isCustomized(definition), isFalse);
      }
      expect(prompts.customizedCount, 0);
      expect(prompts.explainPrompt, AIPrompts.defaultExplainPrompt);
      expect(prompts.quizPrompt, AIPrompts.defaultQuizPrompt);
    });

    test("setPrompt stores, persists, and marks customized", () async {
      final prompts = AIPrompts();
      await prompts.setPrompt(AIPrompts.explainDefinition, "custom text");
      expect(prompts.explainPrompt, "custom text");
      expect(prompts.isCustomized(AIPrompts.explainDefinition), isTrue);
      expect(prompts.customizedCount, 1);
      expect(prefs.getString("customExplainPrompt"), "custom text");

      // A fresh instance reads the stored value back.
      expect(AIPrompts().explainPrompt, "custom text");
    });

    test("setting the default text again clears the stored key", () async {
      final prompts = AIPrompts();
      await prompts.setPrompt(AIPrompts.translateDefinition, "changed");
      expect(prefs.getString("customTranslatePrompt"), "changed");
      await prompts.setPrompt(
        AIPrompts.translateDefinition,
        AIPrompts.defaultTranslatePrompt,
      );
      expect(prompts.isCustomized(AIPrompts.translateDefinition), isFalse);
      expect(prefs.getString("customTranslatePrompt"), isNull);
    });

    test("resetPrompt and resetAllPrompts restore defaults", () async {
      final prompts = AIPrompts();
      await prompts.setQuizPrompt("quiz v2");
      await prompts.setScenarioPrompt("scenario v2");
      expect(prompts.customizedCount, 2);

      await prompts.resetQuizPrompt();
      expect(prompts.quizPrompt, AIPrompts.defaultQuizPrompt);
      expect(prompts.customizedCount, 1);

      await prompts.resetAllPrompts();
      expect(prompts.customizedCount, 0);
      expect(prompts.scenarioPrompt, AIPrompts.defaultScenarioPrompt);
      expect(prefs.getString("customScenarioPrompt"), isNull);
    });

    test("every definition declares its substituted variables", () {
      for (final definition in AIPrompts.allDefinitions) {
        expect(definition.variables, isNotEmpty, reason: definition.id);
        for (final variable in definition.variables) {
          expect(
            definition.defaultText.contains(variable),
            isTrue,
            reason: "${definition.id} should use $variable",
          );
        }
      }
    });
  });
}

import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  test(
    "AI word explanation needs both the switch and a configured provider",
    () async {
      final local = Settings();
      local.aiExplainWord = true;

      expect(isAiExplainWordEnabled(local), isFalse);

      await local.saveAiProviderConfig("openai", "gpt-test", "key-test");
      local.aiProvider = "openai";
      expect(isAiExplainWordEnabled(local), isTrue);

      local.aiExplainWord = false;
      expect(isAiExplainWordEnabled(local), isFalse);
    },
  );

  test("removing the API key hides the AI word page again", () async {
    final local = Settings();
    local.aiExplainWord = true;
    local.aiProvider = "openai";
    await local.saveAiProviderConfig("openai", "gpt-test", "key-test");
    expect(isAiExplainWordEnabled(local), isTrue);

    await local.saveAiProviderConfig("openai", "gpt-test", "");
    expect(isAiExplainWordEnabled(local), isFalse);
  });

  test("keyless providers only need a model", () async {
    final local = Settings();
    local.aiExplainWord = true;
    local.aiProvider = "ollama";
    await local.saveAiProviderConfig("ollama", "llama-test", "");
    expect(isAiExplainWordEnabled(local), isTrue);

    await local.saveAiProviderConfig("ollama", "", "");
    expect(isAiExplainWordEnabled(local), isFalse);
  });

  test("manual mode does not affect tab visibility", () async {
    final local = Settings();
    local.aiExplainWord = true;
    local.aiProvider = "openai";
    local.aiExplainWordManual = true;
    await local.saveAiProviderConfig("openai", "gpt-test", "key-test");

    expect(isAiExplainWordEnabled(local), isTrue);
    expect(shouldAutoRequestAiExplanation(local), isFalse);
  });

  test("saving provider config notifies word-display listeners", () async {
    final local = Settings();
    var notifications = 0;
    local.addListener(() => notifications++);

    await local.saveAiProviderConfig("openai", "gpt-test", "key-test");

    expect(notifications, 1);
  });
}

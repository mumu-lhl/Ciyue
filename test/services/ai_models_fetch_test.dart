import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/models/ai/ai.dart";
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

  test("ModelProviderManager has updated default models for all providers", () {
    final openaiModels = ModelProviderManager.getModels("openai");
    expect(openaiModels.any((m) => m.originName == "gpt-6-astra"), isTrue);
    expect(openaiModels.any((m) => m.originName == "gpt-6-sol"), isTrue);
    expect(openaiModels.any((m) => m.originName == "gpt-6-luna"), isTrue);
    expect(openaiModels.any((m) => m.originName == "gpt-5.6-sol"), isTrue);
    expect(openaiModels.any((m) => m.originName == "gpt-5"), isTrue);
    expect(openaiModels.any((m) => m.originName == "gpt-5-mini"), isTrue);
    expect(openaiModels.any((m) => m.originName == "o3"), isTrue);
    expect(openaiModels.any((m) => m.originName == "o4-mini"), isTrue);
    expect(openaiModels.any((m) => m.originName == "gpt-4.1"), isTrue);
    expect(openaiModels.any((m) => m.originName == "gpt-4o"), isTrue);
    expect(openaiModels.any((m) => m.originName == "gpt-4o-mini"), isTrue);
    expect(openaiModels.any((m) => m.originName == "gpt-3.5-turbo"), isFalse);
    expect(openaiModels.any((m) => m.originName == "gpt-4-turbo"), isFalse);

    final geminiModels = ModelProviderManager.getModels("gemini");
    expect(geminiModels.any((m) => m.originName == "gemini-3.8-flash"), isTrue);
    expect(geminiModels.any((m) => m.originName == "gemini-3.5-flash"), isTrue);
    expect(geminiModels.any((m) => m.originName == "gemini-2.5-pro"), isTrue);
    expect(geminiModels.any((m) => m.originName == "gemini-2.5-flash"), isTrue);
    expect(geminiModels.any((m) => m.originName == "gemini-2.0-flash"), isTrue);

    final deepseekModels = ModelProviderManager.getModels("deepseek");
    expect(deepseekModels.any((m) => m.originName == "deepseek-flash"), isTrue);
    expect(
      deepseekModels.any((m) => m.originName == "deepseek-v4-pro"),
      isTrue,
    );
    expect(deepseekModels.any((m) => m.originName == "deepseek-chat"), isTrue);
    expect(
      deepseekModels.any((m) => m.originName == "deepseek-reasoner"),
      isTrue,
    );

    final anthropicModels = ModelProviderManager.getModels("anthropic");
    expect(
      anthropicModels.any((m) => m.originName == "claude-opus-5-5"),
      isTrue,
    );
    expect(
      anthropicModels.any((m) => m.originName == "claude-sonnet-5"),
      isTrue,
    );
    expect(
      anthropicModels.any((m) => m.originName == "claude-opus-4-0"),
      isTrue,
    );
    expect(
      anthropicModels.any((m) => m.originName == "claude-sonnet-4-0"),
      isTrue,
    );
    expect(
      anthropicModels.any((m) => m.originName == "claude-3-7-sonnet-latest"),
      isTrue,
    );

    final xaiModels = ModelProviderManager.getModels("xai");
    expect(xaiModels.any((m) => m.originName == "grok-4.7"), isTrue);
    expect(xaiModels.any((m) => m.originName == "grok-4"), isTrue);
    expect(xaiModels.any((m) => m.originName == "grok-3"), isTrue);

    final zhipuModels = ModelProviderManager.getModels("zhipu");
    expect(zhipuModels.any((m) => m.originName == "glm-5.3"), isTrue);
    expect(zhipuModels.any((m) => m.originName == "glm-5.2"), isTrue);
    expect(zhipuModels.any((m) => m.originName == "glm-4-plus"), isTrue);
    expect(zhipuModels.any((m) => m.originName == "glm-z1-air"), isTrue);

    final openrouterModels = ModelProviderManager.getModels("openrouter");
    expect(openrouterModels.isNotEmpty, isTrue);
    expect(
      openrouterModels.any((m) => m.originName.contains("deepseek-r1")),
      isTrue,
    );

    final siliconflowModels = ModelProviderManager.getModels("siliconflow");
    expect(siliconflowModels.isNotEmpty, isTrue);

    final ollamaModels = ModelProviderManager.getModels("ollama");
    expect(ollamaModels.isNotEmpty, isTrue);
  });

  test(
    "ModelProviderManager.getModels returns fetched models when available",
    () async {
      const provider = "deepseek";
      final customModels = [
        const ModelInfo("deepseek-custom-1", "Custom 1"),
        const ModelInfo("deepseek-custom-2", "Custom 2"),
      ];

      await settings.saveFetchedModels(provider, customModels);

      final retrieved = ModelProviderManager.getModels(provider);
      expect(retrieved.length, equals(2));
      expect(retrieved[0].originName, equals("deepseek-custom-1"));
      expect(retrieved[1].originName, equals("deepseek-custom-2"));
    },
  );

  test(
    "fetchModels throws exception when API key is empty for secured providers",
    () async {
      expect(
        () =>
            ModelProviderManager.fetchModels(provider: "openai", apiKey: "  "),
        throwsA(isA<Exception>()),
      );
      expect(
        () => ModelProviderManager.fetchModels(provider: "gemini", apiKey: ""),
        throwsA(isA<Exception>()),
      );
      expect(
        () => ModelProviderManager.fetchModels(
          provider: "anthropic",
          apiKey: " ",
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        () =>
            ModelProviderManager.fetchModels(provider: "deepseek", apiKey: ""),
        throwsA(isA<Exception>()),
      );
    },
  );
}

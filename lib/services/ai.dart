import "dart:convert";

import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/core/http_client.dart";
import "package:dio/dio.dart";

class AI {
  final String provider;
  final String model;
  final String apikey;
  late final AIProvider aiProvider;

  AI({
    required this.provider,
    required this.model,
    required this.apikey,
  }) {
    if (provider == "gemini") {
      aiProvider = GeminiProvider(apikey: apikey, model: model);
    } else if (provider == "ollama") {
      aiProvider = OllamaProvider(model: model, apiUrl: settings.aiAPIUrl);
    } else {
      aiProvider = OpenAICompatibleProvider(
        provider: provider,
        apikey: apikey,
        model: model,
      );
    }
  }

  Future<String> request(String prompt) async {
    return aiProvider.request(prompt);
  }
}

abstract class AIProvider {
  Future<String> request(String prompt);
}

class GeminiProvider implements AIProvider {
  final String apikey;
  final String model;

  GeminiProvider({required this.apikey, required this.model});

  @override
  Future<String> request(String prompt) async {
    final formattedApiUrl = ModelProviderManager
        .modelProviders["gemini"]!.apiUrl
        .replaceFirst("{model}", model);

    final params = {"key": apikey};

    final headers = {
      "Content-Type": "application/json",
    };
    final data = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    };

    try {
      final response = await AppHttp.post(
        formattedApiUrl,
        query: params,
        headers: headers,
        data: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final decodedResponse = response.data;
        return decodedResponse["candidates"][0]["content"]["parts"][0]["text"];
      } else {
        throw Exception(
            "Failed to fetch response from Gemini API. Status code: ${response.statusCode}, body: ${response.data}");
      }
    } catch (e) {
      throw Exception("Error requesting Gemini API: $e");
    }
  }
}

class ModelProviderManager {
  static const Map<String, ModelProvider> modelProviders = {
    "openai": ModelProvider(
        name: "openai",
        displayedName: "OpenAI",
        apiUrl: "https://api.openai.com/v1/chat/completions",
        models: [
          ModelInfo("gpt-5-mini", "GPT-5 mini"),
          ModelInfo("gpt-5-nano", "GPT-5 nano"),
          ModelInfo("gpt-5-chat-latest", "GPT-5 Chat"),
          ModelInfo("gpt-5", "GPT-5"),
          ModelInfo("gpt-4o-mini", "GPT-4o mini"),
          ModelInfo("gpt-4.1-mini", "GPT-4.1 mini"),
          ModelInfo("gpt-4.1-nano", "GPT-4.1 nano"),
          ModelInfo("gpt-4.1", "GPT-4.1"),
          ModelInfo("gpt-4o", "GPT-4o"),
          ModelInfo("gpt-4.5-preview", "GPT-4.5 Preview"),
          ModelInfo("o1-pro", "o1-pro"),
          ModelInfo("o3", "o3"),
          ModelInfo("o1", "o1"),
          ModelInfo("o4-mini", "o4-mini"),
          ModelInfo("o3-mini", "o3-mini"),
          ModelInfo("o1-mini", "o1-mini"),
        ]),
    "gemini": ModelProvider(
        name: "gemini",
        displayedName: "Gemini",
        apiUrl:
            "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        models: [
          ModelInfo("gemini-2.5-flash", "Gemini 2.5 Flash"),
          ModelInfo("gemini-2.5-flash-lite", "Gemini 2.5 Flash Lite"),
          ModelInfo("gemini-2.5-pro", "Gemini 2.5 Pro"),
          ModelInfo("gemini-2.5-pro-exp-03-25", "Gemini 2.5 Pro"),
          ModelInfo("gemini-2.0-flash", "Gemini 2.0 Flash"),
          ModelInfo("gemini-2.0-flash-lite", "Gemini 2.0 Flash Lite"),
          ModelInfo("gemini-2.0-flash-thinking-exp-01-21",
              "Gemini 2.0 Flash Thinking"),
          ModelInfo("gemini-2.0-pro-exp-02-05", "Gemini 2.0 Pro"),
          ModelInfo("gemini-1.5-pro", "Gemini 1.5 Pro"),
          ModelInfo("gemini-1.5-flash", "Gemini 1.5 Flash"),
          ModelInfo("gemini-1.5-flash-8b", "Gemini 1.5 Flash-8B"),
        ]),
    "deepseek": ModelProvider(
        name: "deepseek",
        displayedName: "DeepSeek",
        apiUrl: "https://api.deepseek.com/chat/completions",
        models: [
          ModelInfo("deepseek-chat", "DeepSeek Chat"),
          ModelInfo("deepseek-reasoner", "DeepSeek Reasoner"),
        ]),
    "anthropic": ModelProvider(
        name: "anthropic",
        displayedName: "Anthropic",
        apiUrl: "https://api.anthropic.com/v1/messages",
        models: [
          ModelInfo("claude-opus-4-0", "Claude Opus 4"),
          ModelInfo("claude-sonnet-4-0", "Claude Sonnet 4"),
          ModelInfo("claude-3-7-sonnet-latest", "Claude Sonnet 3.7"),
          ModelInfo("claude-3-5-sonnet-latest", "Claude Sonnet 3.5"),
          ModelInfo("claude-3-5-haiku-latest", "Claude Haiku 3.5"),
          ModelInfo("claude-3-sonnet-20240229", "Claude Sonnet 3"),
          ModelInfo("claude-3-haiku-20240307", "Claude Haiku 3"),
          ModelInfo("claude-3-opus-latest", "Claude Opus 3"),
        ]),
    "openrouter": ModelProvider(
        name: "openrouter",
        displayedName: "OpenRouter",
        apiUrl: "https://openrouter.ai/api/v1/chat/completions",
        models: [],
        allowCustomModel: true),
    "siliconflow": ModelProvider(
        name: "siliconflow",
        displayedName: "SiliconFlow",
        apiUrl: "https://api.ap.siliconflow.com/v1/chat/completions",
        models: [],
        allowCustomModel: true),
    "siliconflowcn": ModelProvider(
        name: "siliconflowcn",
        displayedName: "SiliconFlow China",
        apiUrl: "https://api.siliconflow.cn/v1/chat/completions",
        models: [],
        allowCustomModel: true),
    "zhipu": ModelProvider(
      name: "zhipu",
      displayedName: "智谱",
      apiUrl: "https://open.bigmodel.cn/api/paas/v4/chat/completions",
      models: [
        ModelInfo("glm-4-plus", "GLM-4 Plus"),
        ModelInfo("glm-4-air-250414", "GLM-4 Air 250414"),
        ModelInfo("glm-4-airx", "GLM-4 AirX"),
        ModelInfo("glm-4-long", "GLM-4 Long"),
        ModelInfo("glm-4-flashx", "GLM-4 FlashX"),
        ModelInfo("glm-4-flash-250414", "GLM-4 Flash 250414"),
        ModelInfo("glm-z1-air", "GLM-Z1 Air"),
        ModelInfo("glm-z1-airx", "GLM-Z1 AirX"),
        ModelInfo("glm-z1-flash", "GLM-Z1 Flash"),
      ],
    ),
    "xai": ModelProvider(
      name: "xai",
      displayedName: "xAI",
      apiUrl: "https://api.x.ai/v1/chat/completions",
      models: [
        ModelInfo("grok-4", "Grok 4"),
        ModelInfo("grok-3", "Grok 3"),
        ModelInfo("grok-3-fast", "Grok 3 Fast"),
        ModelInfo("grok-3-mini", "Grok 3 Mini"),
        ModelInfo("grok-3-mini-fast", "Grok 3 Mini Fast"),
        ModelInfo("grok-2-vision", "Grok 2 Vision"),
      ],
    ),
    "openai_compatible": ModelProvider(
      name: "openai_compatible",
      displayedName: "OpenAI Compatible",
      apiUrl: "",
      models: [],
      allowCustomModel: true,
      allowCustomAPIUrl: true,
    ),
    "ollama": ModelProvider(
      name: "ollama",
      displayedName: "Ollama",
      apiUrl: "http://localhost:11434/api/chat",
      models: [],
      allowCustomModel: true,
      allowCustomAPIUrl: true,
    ),
  };
}

class OllamaProvider implements AIProvider {
  final String model;
  final String apiUrl;

  const OllamaProvider({required this.model, required this.apiUrl});

  @override
  Future<String> request(String prompt) async {
    final headers = {
      "Content-Type": "application/json",
    };

    final data = {
      "model": model,
      "messages": [
        {"role": "user", "content": prompt}
      ],
      "stream": false
    };

    try {
      final response = await AppHttp.post(
        apiUrl,
        headers: headers,
        data: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final decodedResponse = response.data;
        return decodedResponse["message"]["content"];
      } else {
        throw Exception(
            "Failed to fetch response from Ollama API. Status code: ${response.statusCode}, body: ${response.data}");
      }
    } on DioException catch (e) {
      throw Exception("Error requesting Ollama API: $e\nBody: ${e.response}");
    }
  }
}

class OpenAICompatibleProvider implements AIProvider {
  final String provider;
  final String apikey;
  final String model;
  late final String apiUrl;

  OpenAICompatibleProvider({
    required this.provider,
    required this.apikey,
    required this.model,
  }) {
    if (provider == "openai_compatible") {
      final aiAPIUrl = settings.aiAPIUrl;
      if (aiAPIUrl.endsWith("/chat/completions")) {
        apiUrl = aiAPIUrl;
      } else {
        apiUrl = "$aiAPIUrl/chat/completions";
      }
    } else if (ModelProviderManager.modelProviders.containsKey(provider)) {
      apiUrl = ModelProviderManager.modelProviders[provider]!.apiUrl;
    } else {
      apiUrl = ModelProviderManager.modelProviders["openai"]!.apiUrl;
    }
  }

  @override
  Future<String> request(String prompt) async {
    final headers = {
      "Content-Type": "application/json",
    };

    if (provider == "anthropic") {
      headers["x-api-key"] = apikey;
    } else {
      headers["Authorization"] = "Bearer $apikey";
    }

    // OpenRouter App Attribution
    if (provider == "openrouter") {
      headers["HTTP-Referer"] = "https://github.com/mumu-lhl/Ciyue";
      headers["X-Title"] = "Ciyue";
    }

    final data = {
      "model": model,
      "messages": [
        {"role": "user", "content": prompt}
      ]
    };

    try {
      final response = await AppHttp.post(
        apiUrl,
        headers: headers,
        data: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final decodedResponse = response.data;
        return decodedResponse["choices"][0]["message"]["content"];
      } else {
        throw Exception(
            "Failed to fetch response from OpenAI API. Status code: ${response.statusCode}, body: ${response.data}");
      }
    } on DioException catch (e) {
      throw Exception("Error requesting OpenAI API: $e\nBody: ${e.response}");
    }
  }
}

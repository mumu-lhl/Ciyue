import 'dart:convert';

import 'package:dio/dio.dart';

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
    if (provider == 'gemini') {
      aiProvider = GeminiProvider(apikey: apikey, model: model);
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

class GeminiProvider extends AIProvider {
  final String apikey;
  final String model;

  GeminiProvider({required this.apikey, required this.model});

  @override
  Future<String> request(String prompt) async {
    final dio = Dio();
    final formattedApiUrl = ModelProviderManager
        .modelProviders['gemini']!.apiUrl
        .replaceFirst('{model}', model);

    final params = {'key': apikey};

    final headers = {
      'Content-Type': 'application/json',
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
      final response = await dio.post(
        formattedApiUrl,
        queryParameters: params,
        options: Options(headers: headers),
        data: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final decodedResponse = response.data;
        return decodedResponse['candidates'][0]['content']['parts'][0]['text'];
      } else {
        throw Exception(
            'Failed to fetch response from Gemini API. Status code: ${response.statusCode}, body: ${response.data}');
      }
    } catch (e) {
      throw Exception('Error requesting Gemini API: $e');
    }
  }
}

class ModelInfo {
  final String originName;
  final String shownName;

  const ModelInfo(this.originName, this.shownName);
}

class ModelProvider {
  final String name;
  final String displayedName;
  final String apiUrl;
  final List<ModelInfo> models;
  final bool allowCustomModel;

  const ModelProvider({
    required this.name,
    required this.displayedName,
    required this.apiUrl,
    required this.models,
    this.allowCustomModel = false,
  });
}

class ModelProviderManager {
  static const Map<String, ModelProvider> modelProviders = {
    "openai": ModelProvider(
        name: "openai",
        displayedName: "OpenAI",
        apiUrl: "https://api.openai.com/v1/chat/completions",
        models: [
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
          ModelInfo(
              "gemini-2.5-flash-preview-04-17", "Gemini 2.5 Flash Preview"),
          ModelInfo("gemini-2.5-pro-preview-03-25", "Gemini 2.5 Pro Preview"),
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
        apiUrl: "https://api.openai.com/v1/chat/completions",
        models: [
          ModelInfo("claude-3-7-sonnet-latest", "Claude 3.7 Sonnet"),
          ModelInfo("claude-3-5-sonnet-latest", "Claude 3.5 Sonnet"),
          ModelInfo("claude-3-sonnet-20240229", "Claude 3 Sonnet"),
          ModelInfo("claude-3-5-haiku-latest", "Claude 3.5 Haiku"),
          ModelInfo("claude-3-haiku-20240307", "Claude 3 Haiku"),
          ModelInfo("claude-3-opus-latest", "Claude 3 Opus"),
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
  };
}

class OpenAICompatibleProvider extends AIProvider {
  final String provider;
  final String apikey;
  final String model;
  late final String apiUrl;

  OpenAICompatibleProvider({
    required this.provider,
    required this.apikey,
    required this.model,
  }) {
    if (ModelProviderManager.modelProviders.containsKey(provider)) {
      apiUrl = ModelProviderManager.modelProviders[provider]!.apiUrl;
    } else {
      apiUrl = ModelProviderManager.modelProviders['openai']!.apiUrl;
    }
  }

  @override
  Future<String> request(String prompt) async {
    final dio = Dio();
    final headers = {
      'Content-Type': 'application/json',
    };

    if (provider == 'anthropic') {
      headers['x-api-key'] = apikey;
    } else {
      headers['Authorization'] = 'Bearer $apikey';
    }

    final data = {
      "model": model,
      "messages": [
        {"role": "user", "content": prompt}
      ]
    };

    try {
      final response = await dio.post(
        apiUrl,
        options: Options(headers: headers),
        data: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final decodedResponse = response.data;
        return decodedResponse['choices'][0]['message']['content'];
      } else {
        throw Exception(
            'Failed to fetch response from OpenAI API. Status code: ${response.statusCode}, body: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('Error requesting OpenAI API: $e\nBody: ${e.response}');
    }
  }
}

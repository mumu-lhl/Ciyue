import "dart:convert";

import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/services/settings.dart";
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

  Stream<String> requestStream(String prompt) async* {
    yield* aiProvider.requestStream(prompt);
  }
}

abstract class AIProvider {
  Future<String> request(String prompt);

  Stream<String> requestStream(String prompt);
}

class GeminiProvider implements AIProvider {
  final String apikey;
  final String model;

  GeminiProvider({required this.apikey, required this.model});

  @override
  Future<String> request(String prompt) async {
    final dio = Dio();
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
      final response = await dio.post(
        formattedApiUrl,
        queryParameters: params,
        options: Options(headers: headers),
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

  @override
  Stream<String> requestStream(String prompt) async* {
    final dio = Dio();
    final formattedApiUrl = ModelProviderManager
        .modelProviders["gemini"]!.apiUrl
        .replaceFirst("{model}", model)
        .replaceFirst("generateContent", "streamGenerateContent");

    final params = {"key": apikey};

    final headers = {
      "Content-Type": "application/json",
      "Accept": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
    };
    final data = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ],
      "generationConfig": {
        "responseMimeType": "text/plain",
      },
    };

    try {
      final response = await dio.post(
        formattedApiUrl,
        queryParameters: params,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
        data: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        await for (var chunk in response.data!.stream) {
          final String decodedChunk = utf8.decode(chunk);
          final List<String> lines = decodedChunk
              .split("\n")
              .where((line) => line.isNotEmpty)
              .toList();

          for (var line in lines) {
            try {
              final Map<String, dynamic> json = jsonDecode(line);
              if (json["candidates"] != null &&
                  json["candidates"][0]["content"] != null &&
                  json["candidates"][0]["content"]["parts"] != null &&
                  json["candidates"][0]["content"]["parts"][0]["text"] !=
                      null) {
                yield json["candidates"][0]["content"]["parts"][0]["text"];
              }
            } catch (e) {
              // Ignore malformed JSON lines or non-text parts
            }
          }
        }
      } else {
        throw Exception(
            "Failed to fetch stream from Gemini API. Status code: ${response.statusCode}, body: ${response.data}");
      }
    } on DioException catch (e) {
      throw Exception("Error streaming Gemini API: $e\nBody: ${e.response}");
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
              "gemini-2.5-flash-preview-05-20", "Gemini 2.5 Flash Preview"),
          ModelInfo("gemini-2.5-pro-preview-05-06", "Gemini 2.5 Pro Preview"),
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
        ModelInfo("grok-3-beta", "Grok 3"),
        ModelInfo("grok-3-fast-beta", "Grok 3 Fast"),
        ModelInfo("grok-3-mini-beta", "Grok 3 Mini"),
        ModelInfo("grok-3-mini-fast-beta", "Grok 3 Mini Fast"),
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
    final dio = Dio();
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
      final response = await dio.post(
        apiUrl,
        options: Options(headers: headers),
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

  @override
  Stream<String> requestStream(String prompt) async* {
    final dio = Dio();
    final headers = {
      "Content-Type": "application/json",
    };

    final data = {
      "model": model,
      "messages": [
        {"role": "user", "content": prompt}
      ],
      "stream": true
    };

    try {
      final response = await dio.post(
        apiUrl,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
        data: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        await for (var chunk in response.data!.stream) {
          final String decodedChunk = utf8.decode(chunk);
          final List<String> lines = decodedChunk
              .split("\n")
              .where((line) => line.isNotEmpty)
              .toList();

          for (var line in lines) {
            try {
              final Map<String, dynamic> json = jsonDecode(line);
              if (json["message"] != null && json["message"]["content"] != null) {
                yield json["message"]["content"];
              }
            } catch (e) {
              // Ignore malformed JSON lines or non-text parts
            }
          }
        }
      } else {
        throw Exception(
            "Failed to fetch stream from Ollama API. Status code: ${response.statusCode}, body: ${response.data}");
      }
    } on DioException catch (e) {
      throw Exception("Error streaming Ollama API: $e\nBody: ${e.response}");
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
    if (ModelProviderManager.modelProviders.containsKey(provider)) {
      apiUrl = ModelProviderManager.modelProviders[provider]!.apiUrl;
    } else if (provider == "openai_compatible") {
      apiUrl = settings.aiAPIUrl;
    } else {
      apiUrl = ModelProviderManager.modelProviders["openai"]!.apiUrl;
    }
  }

  @override
  Future<String> request(String prompt) async {
    final dio = Dio();
    final headers = {
      "Content-Type": "application/json",
    };

    if (provider == "anthropic") {
      headers["x-api-key"] = apikey;
    } else {
      headers["Authorization"] = "Bearer $apikey";
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
        return decodedResponse["choices"][0]["message"]["content"];
      } else {
        throw Exception(
            "Failed to fetch response from OpenAI API. Status code: ${response.statusCode}, body: ${response.data}");
      }
    } on DioException catch (e) {
      throw Exception("Error requesting OpenAI API: $e\nBody: ${e.response}");
    }
  }

  @override
  Stream<String> requestStream(String prompt) async* {
    final dio = Dio();
    final headers = {
      "Content-Type": "application/json",
    };

    if (provider == "anthropic") {
      headers["x-api-key"] = apikey;
    } else {
      headers["Authorization"] = "Bearer $apikey";
    }

    final data = {
      "model": model,
      "messages": [
        {"role": "user", "content": prompt}
      ],
      "stream": true
    };

    try {
      final response = await dio.post(
        apiUrl,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
        data: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        await for (var chunk in response.data!.stream) {
          final String decodedChunk = utf8.decode(chunk);
          final List<String> lines = decodedChunk
              .split("\n")
              .where((line) => line.startsWith("data:"))
              .map((line) => line.substring(5).trim())
              .where((line) => line.isNotEmpty && line != "[DONE]")
              .toList();

          for (var line in lines) {
            try {
              final Map<String, dynamic> json = jsonDecode(line);
              if (json["choices"] != null &&
                  json["choices"][0]["delta"] != null &&
                  json["choices"][0]["delta"]["content"] != null) {
                yield json["choices"][0]["delta"]["content"];
              }
            } catch (e) {
              // Ignore malformed JSON lines or non-text parts
            }
          }
        }
      } else {
        throw Exception(
            "Failed to fetch stream from OpenAI API. Status code: ${response.statusCode}, body: ${response.data}");
      }
    } on DioException catch (e) {
      throw Exception("Error streaming OpenAI API: $e\nBody: ${e.response}");
    }
  }
}

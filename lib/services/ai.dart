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

  AI({required this.provider, required this.model, required this.apikey}) {
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
        .modelProviders["gemini"]!
        .apiUrl
        .replaceFirst("{model}", model);

    final params = {"key": apikey};

    final headers = {"Content-Type": "application/json"};
    final data = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
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
          "Failed to fetch response from Gemini API. Status code: ${response.statusCode}, body: ${response.data}",
        );
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
        ModelInfo("gpt-6-astra", "GPT-6 Astra"),
        ModelInfo("gpt-6-sol", "GPT-6 Sol"),
        ModelInfo("gpt-6-luna", "GPT-6 Luna"),
        ModelInfo("gpt-5.6-sol", "GPT-5.6 Sol"),
        ModelInfo("gpt-5.6-terra", "GPT-5.6 Terra"),
        ModelInfo("gpt-5.6-luna", "GPT-5.6 Luna"),
        ModelInfo("gpt-5", "GPT-5"),
        ModelInfo("gpt-5-mini", "GPT-5 mini"),
        ModelInfo("gpt-5-nano", "GPT-5 nano"),
        ModelInfo("gpt-5-chat-latest", "GPT-5 Chat"),
        ModelInfo("o3", "o3"),
        ModelInfo("o3-pro", "o3-pro"),
        ModelInfo("o3-mini", "o3-mini"),
        ModelInfo("o4-mini", "o4-mini"),
        ModelInfo("o1", "o1"),
        ModelInfo("o1-pro", "o1-pro"),
        ModelInfo("o1-mini", "o1-mini"),
        ModelInfo("gpt-4.5-preview", "GPT-4.5 Preview"),
        ModelInfo("gpt-4.1", "GPT-4.1"),
        ModelInfo("gpt-4.1-mini", "GPT-4.1 mini"),
        ModelInfo("gpt-4.1-nano", "GPT-4.1 nano"),
        ModelInfo("gpt-4o", "GPT-4o"),
        ModelInfo("gpt-4o-mini", "GPT-4o mini"),
        ModelInfo("chatgpt-4o-latest", "ChatGPT-4o Latest"),
      ],
      allowCustomModel: true,
    ),
    "gemini": ModelProvider(
      name: "gemini",
      displayedName: "Gemini",
      apiUrl: "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
      models: [
        ModelInfo("gemini-3.8-flash", "Gemini 3.8 Flash"),
        ModelInfo("gemini-3.8-flash-lite", "Gemini 3.8 Flash Lite"),
        ModelInfo("gemini-3.5-flash", "Gemini 3.5 Flash"),
        ModelInfo("gemini-3.5-flash-lite", "Gemini 3.5 Flash Lite"),
        ModelInfo("gemini-3.1-pro-preview", "Gemini 3.1 Pro Preview"),
        ModelInfo("gemini-2.5-pro", "Gemini 2.5 Pro"),
        ModelInfo("gemini-2.5-flash", "Gemini 2.5 Flash"),
        ModelInfo("gemini-2.5-flash-lite", "Gemini 2.5 Flash Lite"),
        ModelInfo("gemini-2.5-pro-exp-03-25", "Gemini 2.5 Pro Exp"),
        ModelInfo("gemini-2.0-flash", "Gemini 2.0 Flash"),
        ModelInfo("gemini-2.0-flash-lite", "Gemini 2.0 Flash Lite"),
        ModelInfo(
          "gemini-2.0-flash-thinking-exp-01-21",
          "Gemini 2.0 Flash Thinking",
        ),
        ModelInfo("gemini-2.0-pro-exp-02-05", "Gemini 2.0 Pro Exp"),
        ModelInfo("gemini-1.5-pro", "Gemini 1.5 Pro"),
        ModelInfo("gemini-1.5-flash", "Gemini 1.5 Flash"),
        ModelInfo("gemini-1.5-flash-8b", "Gemini 1.5 Flash-8B"),
      ],
      allowCustomModel: true,
    ),
    "deepseek": ModelProvider(
      name: "deepseek",
      displayedName: "DeepSeek",
      apiUrl: "https://api.deepseek.com/chat/completions",
      models: [
        ModelInfo("deepseek-flash", "DeepSeek V4.1 Flash"),
        ModelInfo("deepseek-v4-pro", "DeepSeek V4 Pro"),
        ModelInfo("deepseek-chat", "DeepSeek Chat (V3)"),
        ModelInfo("deepseek-reasoner", "DeepSeek Reasoner (R1)"),
      ],
      allowCustomModel: true,
    ),
    "anthropic": ModelProvider(
      name: "anthropic",
      displayedName: "Anthropic",
      apiUrl: "https://api.anthropic.com/v1/messages",
      models: [
        ModelInfo("claude-opus-5-5", "Claude Opus 5.5"),
        ModelInfo("claude-fable-5-1", "Claude Fable 5.1"),
        ModelInfo("claude-sonnet-5", "Claude Sonnet 5"),
        ModelInfo("claude-haiku-4-5", "Claude Haiku 4.5"),
        ModelInfo("claude-opus-4-0", "Claude Opus 4"),
        ModelInfo("claude-sonnet-4-0", "Claude Sonnet 4"),
        ModelInfo("claude-3-7-sonnet-latest", "Claude Sonnet 3.7"),
        ModelInfo("claude-3-5-sonnet-latest", "Claude Sonnet 3.5"),
        ModelInfo("claude-3-5-haiku-latest", "Claude Haiku 3.5"),
        ModelInfo("claude-3-opus-latest", "Claude Opus 3"),
        ModelInfo("claude-3-sonnet-20240229", "Claude Sonnet 3"),
        ModelInfo("claude-3-haiku-20240307", "Claude Haiku 3"),
      ],
      allowCustomModel: true,
    ),
    "openrouter": ModelProvider(
      name: "openrouter",
      displayedName: "OpenRouter",
      apiUrl: "https://openrouter.ai/api/v1/chat/completions",
      models: [
        ModelInfo("openai/gpt-6-astra", "GPT-6 Astra"),
        ModelInfo("openai/gpt-6-sol", "GPT-6 Sol"),
        ModelInfo("anthropic/claude-opus-5-5", "Claude Opus 5.5"),
        ModelInfo("anthropic/claude-sonnet-5", "Claude Sonnet 5"),
        ModelInfo("google/gemini-3.8-flash", "Gemini 3.8 Flash"),
        ModelInfo("google/gemini-3.5-flash", "Gemini 3.5 Flash"),
        ModelInfo("x-ai/grok-4.7", "Grok 4.7"),
        ModelInfo("deepseek/deepseek-flash", "DeepSeek Flash"),
        ModelInfo("deepseek/deepseek-r1", "DeepSeek R1"),
        ModelInfo("deepseek/deepseek-chat", "DeepSeek V3"),
        ModelInfo("anthropic/claude-3.7-sonnet", "Claude 3.7 Sonnet"),
        ModelInfo("google/gemini-2.5-pro", "Gemini 2.5 Pro"),
        ModelInfo("openai/gpt-4o", "GPT-4o"),
        ModelInfo("meta-llama/llama-3.3-70b-instruct", "Llama 3.3 70B"),
        ModelInfo("qwen/qwen-2.5-72b-instruct", "Qwen 2.5 72B"),
      ],
      allowCustomModel: true,
    ),
    "siliconflow": ModelProvider(
      name: "siliconflow",
      displayedName: "SiliconFlow",
      apiUrl: "https://api.ap.siliconflow.com/v1/chat/completions",
      models: [
        ModelInfo("deepseek-ai/DeepSeek-R1", "DeepSeek R1"),
        ModelInfo("deepseek-ai/DeepSeek-V3", "DeepSeek V3"),
        ModelInfo("Qwen/Qwen2.5-72B-Instruct", "Qwen 2.5 72B"),
        ModelInfo("Qwen/Qwen2.5-32B-Instruct", "Qwen 2.5 32B"),
        ModelInfo("Qwen/Qwen2.5-14B-Instruct", "Qwen 2.5 14B"),
        ModelInfo("Qwen/Qwen2.5-7B-Instruct", "Qwen 2.5 7B"),
        ModelInfo("THUDM/glm-4-9b-chat", "GLM-4 9B Chat"),
        ModelInfo("meta-llama/Meta-Llama-3.1-70B-Instruct", "Llama 3.1 70B"),
        ModelInfo("meta-llama/Meta-Llama-3.1-8B-Instruct", "Llama 3.1 8B"),
      ],
      allowCustomModel: true,
    ),
    "siliconflowcn": ModelProvider(
      name: "siliconflowcn",
      displayedName: "SiliconFlow China",
      apiUrl: "https://api.siliconflow.cn/v1/chat/completions",
      models: [
        ModelInfo("deepseek-ai/DeepSeek-R1", "DeepSeek R1"),
        ModelInfo("deepseek-ai/DeepSeek-V3", "DeepSeek V3"),
        ModelInfo("Qwen/Qwen2.5-72B-Instruct", "Qwen 2.5 72B"),
        ModelInfo("Qwen/Qwen2.5-32B-Instruct", "Qwen 2.5 32B"),
        ModelInfo("Qwen/Qwen2.5-14B-Instruct", "Qwen 2.5 14B"),
        ModelInfo("Qwen/Qwen2.5-7B-Instruct", "Qwen 2.5 7B"),
        ModelInfo("THUDM/glm-4-9b-chat", "GLM-4 9B Chat"),
        ModelInfo("meta-llama/Meta-Llama-3.1-70B-Instruct", "Llama 3.1 70B"),
        ModelInfo("meta-llama/Meta-Llama-3.1-8B-Instruct", "Llama 3.1 8B"),
      ],
      allowCustomModel: true,
    ),
    "zhipu": ModelProvider(
      name: "zhipu",
      displayedName: "智谱",
      apiUrl: "https://open.bigmodel.cn/api/paas/v4/chat/completions",
      models: [
        ModelInfo("glm-5.3", "GLM-5.3"),
        ModelInfo("glm-5.3-flash", "GLM-5.3 Flash"),
        ModelInfo("glm-5.2", "GLM-5.2"),
        ModelInfo("glm-5.1", "GLM-5.1"),
        ModelInfo("glm-5", "GLM-5"),
        ModelInfo("glm-4.5", "GLM-4.5"),
        ModelInfo("glm-4-plus", "GLM-4 Plus"),
        ModelInfo("glm-z1-air", "GLM-Z1 Air"),
        ModelInfo("glm-z1-airx", "GLM-Z1 AirX"),
        ModelInfo("glm-z1-flash", "GLM-Z1 Flash"),
        ModelInfo("glm-zero-preview", "GLM Zero Preview"),
        ModelInfo("glm-4-air-250414", "GLM-4 Air 250414"),
        ModelInfo("glm-4-airx", "GLM-4 AirX"),
        ModelInfo("glm-4-long", "GLM-4 Long"),
        ModelInfo("glm-4-flash", "GLM-4 Flash"),
        ModelInfo("glm-4-flashx", "GLM-4 FlashX"),
        ModelInfo("glm-4-flash-250414", "GLM-4 Flash 250414"),
      ],
      allowCustomModel: true,
    ),
    "xai": ModelProvider(
      name: "xai",
      displayedName: "xAI",
      apiUrl: "https://api.x.ai/v1/chat/completions",
      models: [
        ModelInfo("grok-4.7", "Grok 4.7"),
        ModelInfo("grok-4.7-fast", "Grok 4.7 Fast"),
        ModelInfo("grok-4", "Grok 4"),
        ModelInfo("grok-3", "Grok 3"),
        ModelInfo("grok-3-fast", "Grok 3 Fast"),
        ModelInfo("grok-3-mini", "Grok 3 Mini"),
        ModelInfo("grok-3-mini-fast", "Grok 3 Mini Fast"),
        ModelInfo("grok-2-vision", "Grok 2 Vision"),
      ],
      allowCustomModel: true,
    ),
    "openai_compatible": ModelProvider(
      name: "openai_compatible",
      displayedName: "OpenAI Compatible",
      apiUrl: "",
      models: [
        ModelInfo("gpt-6-astra", "GPT-6 Astra"),
        ModelInfo("gpt-6-sol", "GPT-6 Sol"),
        ModelInfo("grok-4.7", "Grok 4.7"),
        ModelInfo("gemini-3.8-flash", "Gemini 3.8 Flash"),
        ModelInfo("claude-sonnet-5", "Claude Sonnet 5"),
        ModelInfo("deepseek-flash", "DeepSeek Flash"),
        ModelInfo("gpt-5", "GPT-5"),
        ModelInfo("gpt-4o", "GPT-4o"),
        ModelInfo("deepseek-chat", "DeepSeek Chat"),
        ModelInfo("deepseek-reasoner", "DeepSeek Reasoner"),
      ],
      allowCustomModel: true,
      allowCustomAPIUrl: true,
    ),
    "ollama": ModelProvider(
      name: "ollama",
      displayedName: "Ollama",
      apiUrl: "http://localhost:11434/api/chat",
      models: [
        ModelInfo("deepseek-r1:latest", "DeepSeek R1"),
        ModelInfo("llama3.3:latest", "Llama 3.3"),
        ModelInfo("qwen2.5:latest", "Qwen 2.5"),
        ModelInfo("gemma2:latest", "Gemma 2"),
        ModelInfo("mistral:latest", "Mistral"),
      ],
      allowCustomModel: true,
      allowCustomAPIUrl: true,
    ),
  };

  static List<ModelInfo> getModels(String provider) {
    final fetched = settings.getFetchedModels(provider);
    if (fetched.isNotEmpty) {
      return fetched;
    }
    return modelProviders[provider]?.models ?? [];
  }

  static Future<List<ModelInfo>> fetchModels({
    required String provider,
    required String apiKey,
    String? customApiUrl,
  }) async {
    final trimmedKey = apiKey.trim();

    if (provider == "gemini") {
      if (trimmedKey.isEmpty) {
        throw Exception("API key is required to fetch Gemini models");
      }
      final response = await AppHttp.get(
        "https://generativelanguage.googleapis.com/v1beta/models",
        query: {"key": trimmedKey},
      );
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      final rawModels = data["models"] as List? ?? [];
      final result = <ModelInfo>[];
      for (final m in rawModels) {
        final name = m["name"] as String? ?? "";
        final methods = m["supportedGenerationMethods"] as List? ?? [];
        if (!methods.contains("generateContent")) continue;
        final id = name.replaceFirst("models/", "");
        final displayName = m["displayName"] as String? ?? id;
        result.add(ModelInfo(id, displayName));
      }
      return result;
    }

    if (provider == "ollama") {
      var url = customApiUrl ?? settings.aiAPIUrl;
      if (url.trim().isEmpty) {
        url = "http://localhost:11434/api/tags";
      } else if (url.contains("/api/chat")) {
        url = url.replaceAll("/api/chat", "/api/tags");
      } else if (url.endsWith("/")) {
        url = "${url}api/tags";
      } else {
        url = "$url/api/tags";
      }
      final response = await AppHttp.get(url);
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      final rawModels = data["models"] as List? ?? [];
      final result = <ModelInfo>[];
      for (final m in rawModels) {
        final name = (m["name"] ?? m["model"]) as String? ?? "";
        if (name.isNotEmpty) {
          result.add(ModelInfo(name, name));
        }
      }
      return result;
    }

    if (provider == "anthropic") {
      if (trimmedKey.isEmpty) {
        throw Exception("API key is required to fetch Anthropic models");
      }
      final response = await AppHttp.get(
        "https://api.anthropic.com/v1/models",
        headers: {"x-api-key": trimmedKey, "anthropic-version": "2023-06-01"},
      );
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      final rawModels = data["data"] as List? ?? [];
      final result = <ModelInfo>[];
      for (final m in rawModels) {
        final id = m["id"] as String? ?? "";
        final name = m["display_name"] as String? ?? id;
        if (id.isNotEmpty) {
          result.add(ModelInfo(id, name));
        }
      }
      return result;
    }

    final String url;
    final headers = <String, String>{"Content-Type": "application/json"};
    if (trimmedKey.isNotEmpty) {
      headers["Authorization"] = "Bearer $trimmedKey";
    }

    switch (provider) {
      case "openai":
        if (trimmedKey.isEmpty) {
          throw Exception("API key is required to fetch OpenAI models");
        }
        url = "https://api.openai.com/v1/models";
      case "deepseek":
        if (trimmedKey.isEmpty) {
          throw Exception("API key is required to fetch DeepSeek models");
        }
        url = "https://api.deepseek.com/models";
      case "xai":
        if (trimmedKey.isEmpty) {
          throw Exception("API key is required to fetch xAI models");
        }
        url = "https://api.x.ai/v1/models";
      case "openrouter":
        headers["HTTP-Referer"] = "https://github.com/mumu-lhl/Ciyue";
        headers["X-Title"] = "Ciyue";
        url = "https://openrouter.ai/api/v1/models";
      case "siliconflow":
        if (trimmedKey.isEmpty) {
          throw Exception("API key is required to fetch SiliconFlow models");
        }
        url = "https://api.ap.siliconflow.com/v1/models?sub_type=chat";
      case "siliconflowcn":
        if (trimmedKey.isEmpty) {
          throw Exception("API key is required to fetch SiliconFlow models");
        }
        url = "https://api.siliconflow.cn/v1/models?sub_type=chat";
      case "zhipu":
        if (trimmedKey.isEmpty) {
          throw Exception("API key is required to fetch Zhipu models");
        }
        url = "https://open.bigmodel.cn/api/paas/v4/models";
      case "openai_compatible":
        var base = (customApiUrl != null && customApiUrl.isNotEmpty)
            ? customApiUrl
            : settings.aiAPIUrl;
        if (base.endsWith("/chat/completions")) {
          url = base.replaceAll("/chat/completions", "/models");
        } else if (base.endsWith("/v1")) {
          url = "$base/models";
        } else if (base.endsWith("/")) {
          url = "${base}models";
        } else {
          url = "$base/models";
        }
      default:
        throw Exception("Unsupported provider for fetching models: $provider");
    }

    final response = await AppHttp.get(url, headers: headers);
    final data = response.data is String
        ? jsonDecode(response.data)
        : response.data;
    final rawModels = data["data"] as List? ?? [];
    final result = <ModelInfo>[];
    for (final m in rawModels) {
      final id = m["id"] as String? ?? "";
      final name = m["name"] as String? ?? id;
      if (id.isNotEmpty) {
        result.add(ModelInfo(id, name));
      }
    }

    if (provider == "openai") {
      result.retainWhere((m) {
        final id = m.originName.toLowerCase();
        if (id.contains("embedding") ||
            id.contains("whisper") ||
            id.contains("tts") ||
            id.contains("dall-e") ||
            id.contains("moderation") ||
            id.contains("davinci") ||
            id.contains("babbage")) {
          return false;
        }
        return id.startsWith("gpt-") ||
            RegExp(r"^o\d").hasMatch(id) ||
            id.startsWith("chatgpt-");
      });
    }

    return result;
  }
}

class OllamaProvider implements AIProvider {
  final String model;
  final String apiUrl;

  const OllamaProvider({required this.model, required this.apiUrl});

  @override
  Future<String> request(String prompt) async {
    final headers = {"Content-Type": "application/json"};

    final data = {
      "model": model,
      "messages": [
        {"role": "user", "content": prompt},
      ],
      "stream": false,
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
          "Failed to fetch response from Ollama API. Status code: ${response.statusCode}, body: ${response.data}",
        );
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
    final headers = {"Content-Type": "application/json"};

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
        {"role": "user", "content": prompt},
      ],
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
          "Failed to fetch response from OpenAI API. Status code: ${response.statusCode}, body: ${response.data}",
        );
      }
    } on DioException catch (e) {
      throw Exception("Error requesting OpenAI API: $e\nBody: ${e.response}");
    }
  }
}

import "dart:convert";
import "dart:typed_data";

import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/core/http_client.dart";
import "package:dio/dio.dart";
import "package:genkit/genkit.dart" hide ModelInfo;
import "package:genkit_anthropic/genkit_anthropic.dart";
import "package:genkit_google_genai/genkit_google_genai.dart";
import "package:genkit_openai/genkit_openai.dart";

/// Thrown when an AI feature is used before the provider has the
/// configuration it needs (model and, for hosted providers, an API
/// key). AI entry points must fail loudly with this instead of
/// silently producing nothing: an unconfigured provider otherwise
/// tends to surface as an empty response or a blank UI.
class AiNotConfiguredException implements Exception {
  final String provider;
  final bool missingModel;
  final bool missingApiKey;

  const AiNotConfiguredException(
    this.provider, {
    required this.missingModel,
    required this.missingApiKey,
  });

  @override
  String toString() {
    final missing = [
      if (missingModel) "model",
      if (missingApiKey) "API key",
    ].join(" and ");
    return "AI provider \"$provider\" is not configured: no $missing set. "
        "Set it in AI Settings first.";
  }
}

/// Providers that run against a local endpoint and work without an
/// API key.
const keylessAiProviders = {"ollama", "openai_compatible"};

/// What is missing for [provider] to be usable, based on the config
/// saved in AI Settings. Both flags false means fully configured.
({bool missingModel, bool missingApiKey}) aiConfigurationGaps(String provider) {
  final config = settings.getAiProviderConfig(provider);
  final model = (config["model"]?.toString() ?? "").trim();
  final apiKey = (config["apiKey"]?.toString() ?? "").trim();
  return (
    missingModel: model.isEmpty,
    missingApiKey: !keylessAiProviders.contains(provider) && apiKey.isEmpty,
  );
}

/// Whether [provider] has everything it needs in AI Settings.
bool isAiProviderConfigured(String provider) {
  final gaps = aiConfigurationGaps(provider);
  return !gaps.missingModel && !gaps.missingApiKey;
}

class AI {
  final String provider;
  final String model;
  final String apikey;
  late final AIProvider aiProvider;

  AI({required this.provider, required this.model, required this.apikey}) {
    if (provider == "gemini") {
      aiProvider = GeminiProvider(apikey: apikey, model: model);
    } else if (provider == "anthropic") {
      aiProvider = AnthropicProvider(apikey: apikey, model: model);
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

  /// Fail fast when this instance was built from an incomplete
  /// configuration, instead of letting the provider call surface
  /// as a hang, an empty stream, or an opaque network error.
  void _ensureConfigured() {
    final missingModel = model.trim().isEmpty;
    final missingApiKey =
        !keylessAiProviders.contains(provider) && apikey.trim().isEmpty;
    if (missingModel || missingApiKey) {
      throw AiNotConfiguredException(
        provider,
        missingModel: missingModel,
        missingApiKey: missingApiKey,
      );
    }
  }

  Future<String> request(String prompt) async {
    _ensureConfigured();
    return aiProvider.request(prompt);
  }

  /// Stream the response as text chunks arrive.
  Stream<String> requestStream(String prompt, {CancellationToken? cancel}) {
    _ensureConfigured();
    return aiProvider.requestStream(prompt, cancel: cancel);
  }

  /// Stream with conversation history for multi-turn chat.
  Stream<String> requestStreamWithHistory(
    String prompt, {
    List<ChatTurn> history = const [],
    List<String> promptImages = const [],
    CancellationToken? cancel,
  }) {
    _ensureConfigured();
    return aiProvider.requestStreamWithHistory(
      prompt,
      history: history,
      promptImages: promptImages,
      cancel: cancel,
    );
  }
}

/// A single turn in a conversation.
class ChatTurn {
  final String text;
  final bool isUser;

  /// System instructions (e.g. a roleplay scenario prompt) are sent
  /// with the system role instead of as a fake model turn.
  final bool isSystem;

  const ChatTurn(this.text, this.isUser, {this.isSystem = false});

  const ChatTurn.system(this.text) : isUser = false, isSystem = true;
}

/// Convert [ChatTurn]s to Genkit messages.
List<Message> chatTurnsToGenkitMessages(List<ChatTurn> history) {
  return [
    for (final turn in history)
      Message(
        role: turn.isSystem
            ? Role.system
            : turn.isUser
            ? Role.user
            : Role.model,
        content: [TextPart(text: turn.text)],
      ),
  ];
}

/// Parts for the final user message of a request: the prompt text
/// plus any attached images, given as base64 data URLs, for
/// vision-capable models. Providers/models without vision support
/// reject these at the API, which surfaces as a normal error.
List<Part> promptParts(String prompt, List<String> imageDataUrls) {
  return [
    TextPart(text: prompt),
    for (final dataUrl in imageDataUrls)
      MediaPart(
        media: Media(contentType: dataUrlContentType(dataUrl), url: dataUrl),
      ),
  ];
}

/// The MIME type of a `data:` URL, e.g. `image/png` out of
/// `data:image/png;base64,...`. Null for non-data URLs.
String? dataUrlContentType(String dataUrl) {
  if (!dataUrl.startsWith("data:")) return null;
  final end = dataUrl.indexOf(";");
  return end > 5 ? dataUrl.substring(5, end) : null;
}

abstract class AIProvider {
  Future<String> request(String prompt);

  /// Stream response text chunks. Default implementation falls back to
  /// emitting the full response as a single chunk.
  Stream<String> requestStream(
    String prompt, {
    CancellationToken? cancel,
  }) async* {
    yield await request(prompt);
  }

  /// Stream with conversation history. Default ignores history
  /// and attached images.
  Stream<String> requestStreamWithHistory(
    String prompt, {
    List<ChatTurn> history = const [],
    List<String> promptImages = const [],
    CancellationToken? cancel,
  }) {
    return requestStream(prompt, cancel: cancel);
  }
}

/// Strip a trailing `/chat/completions` (or similar) to get the OpenAI API
/// base URL expected by the Genkit OpenAI plugin.
String _openAIBaseUrl(String apiUrl) {
  var base = apiUrl.trim();
  const suffixes = ["/chat/completions", "/chat/completion"];
  for (final suffix in suffixes) {
    if (base.endsWith(suffix)) {
      base = base.substring(0, base.length - suffix.length);
      break;
    }
  }
  return base;
}

class GeminiProvider implements AIProvider {
  final String apikey;
  final String model;
  late final Genkit _ai;

  GeminiProvider({required this.apikey, required this.model}) {
    _ai = Genkit(plugins: [googleAI(apiKey: apikey)]);
  }

  @override
  Future<String> request(String prompt) async {
    try {
      final response = await _ai.generate(
        model: googleAI.gemini(model),
        prompt: prompt,
      );
      return response.text;
    } catch (e) {
      throw Exception("Error requesting Gemini API: $e");
    }
  }

  @override
  Stream<String> requestStream(
    String prompt, {
    CancellationToken? cancel,
  }) async* {
    try {
      final stream = _ai.generateStream(
        model: googleAI.gemini(model),
        prompt: prompt,
        cancel: cancel,
      );
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text.isNotEmpty) yield text;
      }
      // Surface any error from the stream.
      await stream.onResult;
    } catch (e) {
      throw Exception("Error requesting Gemini API: $e");
    }
  }

  @override
  Stream<String> requestStreamWithHistory(
    String prompt, {
    List<ChatTurn> history = const [],
    List<String> promptImages = const [],
    CancellationToken? cancel,
  }) async* {
    try {
      final messages = [
        ...chatTurnsToGenkitMessages(history),
        Message(role: Role.user, content: promptParts(prompt, promptImages)),
      ];
      final stream = _ai.generateStream(
        model: googleAI.gemini(model),
        messages: messages,
        cancel: cancel,
      );
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text.isNotEmpty) yield text;
      }
      await stream.onResult;
    } catch (e) {
      throw Exception("Error requesting Gemini API: $e");
    }
  }
}

class AnthropicProvider implements AIProvider {
  final String apikey;
  final String model;
  late final Genkit _ai;

  AnthropicProvider({required this.apikey, required this.model}) {
    _ai = Genkit(plugins: [anthropic(apiKey: apikey)]);
  }

  @override
  Future<String> request(String prompt) async {
    try {
      final response = await _ai.generate(
        model: anthropic.model(model),
        prompt: prompt,
      );
      return response.text;
    } catch (e) {
      throw Exception("Error requesting Anthropic API: $e");
    }
  }

  @override
  Stream<String> requestStream(
    String prompt, {
    CancellationToken? cancel,
  }) async* {
    try {
      final stream = _ai.generateStream(
        model: anthropic.model(model),
        prompt: prompt,
        cancel: cancel,
      );
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text.isNotEmpty) yield text;
      }
      await stream.onResult;
    } catch (e) {
      throw Exception("Error requesting Anthropic API: $e");
    }
  }

  @override
  Stream<String> requestStreamWithHistory(
    String prompt, {
    List<ChatTurn> history = const [],
    List<String> promptImages = const [],
    CancellationToken? cancel,
  }) async* {
    try {
      final messages = [
        ...chatTurnsToGenkitMessages(history),
        Message(role: Role.user, content: promptParts(prompt, promptImages)),
      ];
      final stream = _ai.generateStream(
        model: anthropic.model(model),
        messages: messages,
        cancel: cancel,
      );
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text.isNotEmpty) yield text;
      }
      await stream.onResult;
    } catch (e) {
      throw Exception("Error requesting Anthropic API: $e");
    }
  }
}

class OllamaProvider implements AIProvider {
  final String model;
  final String apiUrl;
  late final Genkit _ai;

  OllamaProvider({required this.model, required this.apiUrl}) {
    // Ollama exposes an OpenAI-compatible API under /v1.
    var base = apiUrl.trim();
    if (base.isEmpty) {
      base = "http://localhost:11434/v1";
    } else if (base.contains("/api/chat")) {
      base = base.replaceAll("/api/chat", "/v1");
    } else if (base.endsWith("/")) {
      base = "${base}v1";
    } else if (!base.endsWith("/v1")) {
      base = "$base/v1";
    }
    _ai = Genkit(
      plugins: [
        openAI(
          name: "ollama",
          // Ollama typically needs no key; pass a dummy value when empty
          // so the plugin doesn't fall back to the env var.
          apiKey: "ollama",
          baseUrl: base,
          models: [CustomModelDefinition(name: model)],
        ),
      ],
    );
  }

  @override
  Future<String> request(String prompt) async {
    try {
      final response = await _ai.generate(
        model: openAI.model(model, namespace: "ollama"),
        prompt: prompt,
      );
      return response.text;
    } catch (e) {
      throw Exception("Error requesting Ollama API: $e");
    }
  }

  @override
  Stream<String> requestStream(
    String prompt, {
    CancellationToken? cancel,
  }) async* {
    try {
      final stream = _ai.generateStream(
        model: openAI.model(model, namespace: "ollama"),
        prompt: prompt,
        cancel: cancel,
      );
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text.isNotEmpty) yield text;
      }
      await stream.onResult;
    } catch (e) {
      throw Exception("Error requesting Ollama API: $e");
    }
  }

  @override
  Stream<String> requestStreamWithHistory(
    String prompt, {
    List<ChatTurn> history = const [],
    List<String> promptImages = const [],
    CancellationToken? cancel,
  }) async* {
    try {
      final messages = [
        ...chatTurnsToGenkitMessages(history),
        Message(role: Role.user, content: promptParts(prompt, promptImages)),
      ];
      final stream = _ai.generateStream(
        model: openAI.model(model, namespace: "ollama"),
        messages: messages,
        cancel: cancel,
      );
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text.isNotEmpty) yield text;
      }
      await stream.onResult;
    } catch (e) {
      throw Exception("Error requesting Ollama API: $e");
    }
  }
}

class OpenAICompatibleProvider implements AIProvider {
  final String provider;
  final String apikey;
  final String model;
  late final Genkit _ai;
  late final String namespace;

  OpenAICompatibleProvider({
    required this.provider,
    required this.apikey,
    required this.model,
  }) {
    final String apiUrl;
    if (provider == "openai_compatible") {
      apiUrl = settings.aiAPIUrl;
    } else if (ModelProviderManager.modelProviders.containsKey(provider)) {
      apiUrl = ModelProviderManager.modelProviders[provider]!.apiUrl;
    } else {
      apiUrl = ModelProviderManager.modelProviders["openai"]!.apiUrl;
    }

    namespace = provider;
    final headers = <String, String>{};
    // OpenRouter App Attribution
    if (provider == "openrouter") {
      headers["HTTP-Referer"] = "https://github.com/mumu-lhl/Ciyue";
      headers["X-Title"] = "Ciyue";
    }

    _ai = Genkit(
      plugins: [
        openAI(
          name: namespace,
          apiKey: apikey,
          baseUrl: _openAIBaseUrl(apiUrl),
          models: [CustomModelDefinition(name: model)],
          headers: headers.isEmpty ? null : headers,
        ),
      ],
    );
  }

  @override
  Future<String> request(String prompt) async {
    try {
      final response = await _ai.generate(
        model: openAI.model(model, namespace: namespace),
        prompt: prompt,
      );
      return response.text;
    } catch (e) {
      throw Exception("Error requesting $provider API: $e");
    }
  }

  @override
  Stream<String> requestStream(
    String prompt, {
    CancellationToken? cancel,
  }) async* {
    try {
      final stream = _ai.generateStream(
        model: openAI.model(model, namespace: namespace),
        prompt: prompt,
        cancel: cancel,
      );
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text.isNotEmpty) yield text;
      }
      await stream.onResult;
    } catch (e) {
      throw Exception("Error requesting $provider API: $e");
    }
  }

  @override
  Stream<String> requestStreamWithHistory(
    String prompt, {
    List<ChatTurn> history = const [],
    List<String> promptImages = const [],
    CancellationToken? cancel,
  }) async* {
    try {
      final messages = [
        ...chatTurnsToGenkitMessages(history),
        Message(role: Role.user, content: promptParts(prompt, promptImages)),
      ];
      final stream = _ai.generateStream(
        model: openAI.model(model, namespace: namespace),
        messages: messages,
        cancel: cancel,
      );
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text.isNotEmpty) yield text;
      }
      await stream.onResult;
    } catch (e) {
      throw Exception("Error requesting $provider API: $e");
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
    "agnes": ModelProvider(
      name: "agnes",
      displayedName: "Agnes AI",
      apiUrl: "https://apihub.agnes-ai.com/v1/chat/completions",
      models: [
        ModelInfo("agnes-3.0-flash", "Agnes 3.0 Flash"),
        ModelInfo("agnes-2.5-flash", "Agnes 2.5 Flash"),
        ModelInfo("agnes-2.0-flash", "Agnes 2.0 Flash"),
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

  /// Image-generation models per provider, for the providers whose
  /// APIs can generate images at all. Providers absent here
  /// (Anthropic, DeepSeek, OpenRouter, Ollama) cannot generate
  /// images, and the UI says so instead of failing obscurely.
  static const Map<String, List<ModelInfo>> providerImageModels = {
    "openai": [
      ModelInfo("gpt-image-1", "GPT Image 1"),
      ModelInfo("dall-e-3", "DALL-E 3"),
    ],
    "gemini": [
      ModelInfo("gemini-3.1-flash-image", "Gemini 3.1 Flash Image"),
      ModelInfo("gemini-2.5-flash-image", "Gemini 2.5 Flash Image"),
    ],
    "agnes": [ModelInfo("agnes-image-2.1-flash", "Agnes Image 2.1 Flash")],
    "siliconflow": [
      ModelInfo("Kwai-Kolors/Kolors", "Kolors"),
      ModelInfo("black-forest-labs/FLUX.1-schnell", "FLUX.1 Schnell"),
    ],
    "siliconflowcn": [
      ModelInfo("Kwai-Kolors/Kolors", "Kolors"),
      ModelInfo("black-forest-labs/FLUX.1-schnell", "FLUX.1 Schnell"),
    ],
    "zhipu": [
      ModelInfo("cogview-4", "CogView-4"),
      ModelInfo("cogview-3-flash", "CogView-3 Flash"),
    ],
    "xai": [ModelInfo("grok-2-image", "Grok 2 Image")],
    "openai_compatible": [
      ModelInfo("gpt-image-1", "GPT Image 1"),
      ModelInfo("dall-e-3", "DALL-E 3"),
    ],
  };

  static List<ModelInfo> getImageModels(String provider) =>
      providerImageModels[provider] ?? const [];

  static bool supportsImageGeneration(String provider) =>
      providerImageModels.containsKey(provider);

  /// The provider's `/images/generations` endpoint, derived from
  /// its chat-completions URL. Gemini generates images through the
  /// Genkit path instead, so it returns null here.
  static String? imageGenerationsUrl(String provider, {String? customApiUrl}) {
    if (provider == "gemini") return null;
    final apiUrl = provider == "openai_compatible"
        ? (customApiUrl ?? settings.aiAPIUrl)
        : modelProviders[provider]?.apiUrl;
    if (apiUrl == null || apiUrl.trim().isEmpty) return null;
    final base = _openAIBaseUrl(apiUrl);
    if (base.isEmpty) return null;
    return "$base/images/generations";
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
      case "agnes":
        if (trimmedKey.isEmpty) {
          throw Exception("API key is required to fetch Agnes AI models");
        }
        url = "https://apihub.agnes-ai.com/v1/models";
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

    if (provider == "agnes") {
      // The models endpoint also lists image and video models;
      // the AI features here are text-only.
      result.retainWhere((m) {
        final id = m.originName.toLowerCase();
        return !id.contains("image") && !id.contains("video");
      });
    }

    return result;
  }
}

/// Thrown when the selected provider has no image-generation API.
class AiImageGenerationUnsupported implements Exception {
  final String provider;

  const AiImageGenerationUnsupported(this.provider);

  @override
  String toString() =>
      "AI provider \"$provider\" does not support image generation.";
}

/// Generates one image from a text prompt and returns its bytes.
///
/// Routes per provider family: Gemini image models go through
/// Genkit (they answer with a media part); every other supported
/// provider exposes an OpenAI-style `/images/generations` endpoint
/// whose response is normalized here (URL or base64 payload).
class AiImageGenerator {
  static Future<Uint8List> generate({
    required String provider,
    required String model,
    required String prompt,
    required String apiKey,
    String? customApiUrl,
  }) async {
    if (!ModelProviderManager.supportsImageGeneration(provider)) {
      throw AiImageGenerationUnsupported(provider);
    }
    final missingModel = model.trim().isEmpty;
    final missingApiKey =
        !keylessAiProviders.contains(provider) && apiKey.trim().isEmpty;
    if (missingModel || missingApiKey) {
      throw AiNotConfiguredException(
        provider,
        missingModel: missingModel,
        missingApiKey: missingApiKey,
      );
    }
    if (provider == "gemini") {
      return _generateWithGemini(model: model, prompt: prompt, apiKey: apiKey);
    }
    return _generateWithImagesEndpoint(
      provider: provider,
      model: model,
      prompt: prompt,
      apiKey: apiKey,
      customApiUrl: customApiUrl,
    );
  }

  static Future<Uint8List> _generateWithGemini({
    required String model,
    required String prompt,
    required String apiKey,
  }) async {
    final ai = Genkit(plugins: [googleAI(apiKey: apiKey)]);
    try {
      final response = await ai.generate(
        model: googleAI.gemini(model),
        prompt: prompt,
      );
      final url = response.media?.url ?? "";
      if (!url.startsWith("data:") || !url.contains(",")) {
        throw Exception("The Gemini image model returned no image.");
      }
      return base64Decode(url.substring(url.indexOf(",") + 1));
    } catch (e) {
      throw Exception("Error generating image with Gemini: $e");
    }
  }

  static Future<Uint8List> _generateWithImagesEndpoint({
    required String provider,
    required String model,
    required String prompt,
    required String apiKey,
    String? customApiUrl,
  }) async {
    final url = ModelProviderManager.imageGenerationsUrl(
      provider,
      customApiUrl: customApiUrl,
    );
    if (url == null) {
      throw AiImageGenerationUnsupported(provider);
    }
    final headers = <String, String>{
      "Content-Type": "application/json",
      if (apiKey.trim().isNotEmpty) "Authorization": "Bearer ${apiKey.trim()}",
    };
    final body = <String, dynamic>{
      "model": model,
      "prompt": prompt,
      "n": 1,
      // Agnes requires the response format inside extra_body and
      // answers with a URL.
      if (provider == "agnes") "extra_body": {"response_format": "url"},
    };
    try {
      final response = await AppHttp.dio.post(
        url,
        data: body,
        options: Options(
          headers: headers,
          receiveTimeout: const Duration(seconds: 180),
        ),
      );
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      final (b64, imageUrl) = extractImagePayload(data);
      if (b64 != null && b64.isNotEmpty) {
        return base64Decode(b64);
      }
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final fileResponse = await AppHttp.dio.get<List<int>>(
          imageUrl,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 180),
          ),
        );
        final bytes = fileResponse.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Uint8List.fromList(bytes);
        }
      }
      throw Exception("The image endpoint returned no image.");
    } catch (e) {
      throw Exception("Error generating image with $provider: $e");
    }
  }

  /// Providers disagree on the response shape: OpenAI-style
  /// `data: [{b64_json | url}]`, SiliconFlow `images: [{url}]`.
  static (String?, String?) extractImagePayload(dynamic data) {
    if (data is! Map) return (null, null);
    final list = data["data"] ?? data["images"];
    if (list is List && list.isNotEmpty && list.first is Map) {
      final first = list.first as Map;
      return (first["b64_json"]?.toString(), first["url"]?.toString());
    }
    return (null, null);
  }
}

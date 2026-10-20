import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/chat_scenarios.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:material_ui/material_ui.dart";

class ChatMessage {
  final String text;
  final bool isUser;

  const ChatMessage({required this.text, required this.isUser});

  Map<String, dynamic> toJson() => {"text": text, "isUser": isUser};

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json["text"] as String? ?? "",
    isUser: json["isUser"] as bool? ?? false,
  );
}

/// A preset roleplay scenario for language learning.
class ChatScenario {
  final String id;
  final String titleKey;
  final String systemPrompt;

  const ChatScenario({
    required this.id,
    required this.titleKey,
    required this.systemPrompt,
  });

  /// Human-readable title for use inside AI prompts. Presets store an
  /// l10n key in [titleKey], which must never leak into a prompt;
  /// custom scenarios store their actual title in [titleKey].
  String get promptTitle {
    switch (id) {
      case "restaurant":
        return "At a Restaurant";
      case "travel":
        return "Travel";
      case "business":
        return "Business Meeting";
      case "shopping":
        return "Shopping";
      case "daily":
        return "Daily Chat";
      default:
        return titleKey;
    }
  }

  static const List<ChatScenario> presets = [
    ChatScenario(
      id: "restaurant",
      titleKey: "scenarioRestaurant",
      systemPrompt: "You are a waiter at a restaurant. Roleplay a dining scenario with the user to help them practice ordering food and conversing in a restaurant. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "travel",
      titleKey: "scenarioTravel",
      systemPrompt: "You are a friendly local tour guide. Roleplay a travel scenario with the user to help them practice asking for directions, booking hotels, and sightseeing conversations. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "business",
      titleKey: "scenarioBusiness",
      systemPrompt: "You are a business colleague. Roleplay a workplace scenario with the user to help them practice meetings, emails, and professional small talk. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "shopping",
      titleKey: "scenarioShopping",
      systemPrompt: "You are a shop assistant. Roleplay a shopping scenario with the user to help them practice asking about prices, sizes, and making purchases. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "daily",
      titleKey: "scenarioDaily",
      systemPrompt: "You are a friendly language partner. Have a casual daily conversation with the user to help them practice everyday speaking. Gently correct their language mistakes and suggest more natural expressions.",
    ),
  ];
}

class ChatViewModel extends ChangeNotifier {
  final textController = TextEditingController();
  final focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  late final AI _ai;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  bool _disposed = false;

  /// Incremented whenever the conversation is reset (clear, new
  /// scenario) or the view model is disposed. Streaming loops capture
  /// their generation and stop writing once it no longer matches, so a
  /// stale stream can never write into a fresh conversation.
  int _streamGeneration = 0;

  /// Optional initial context, e.g. the word from the word detail page.
  /// Restored from the persisted history when the chat is reopened
  /// without fresh context.
  String? _initialContext;
  String? get initialContext => _initialContext;

  /// Active scenario for roleplay, null for free chat.
  ChatScenario? _scenario;
  ChatScenario? get scenario => _scenario;

  ChatViewModel({String? initialContext}) : _initialContext = initialContext {
    final config = settings.getAiProviderConfig(settings.aiProvider);
    _ai = AI(
      provider: settings.aiProvider,
      model: config["model"] ?? "",
      apikey: config["apiKey"] ?? "",
    );
    // Restore the previous session when opened without fresh context.
    if (initialContext == null) {
      _restoreHistory();
    }
  }

  /// Persist the last N messages so the conversation survives navigation.
  static const _historyKey = "chatHistory";
  static const _maxPersistedMessages = 100;

  void _persistHistory() {
    try {
      final messages = _messages.length > _maxPersistedMessages
          ? _messages.sublist(_messages.length - _maxPersistedMessages)
          : _messages;
      // Don't persist empty streaming placeholders.
      final clean = messages
          .where((m) => !(m.text.isEmpty && !m.isUser))
          .map((m) => m.toJson())
          .toList();
      prefs.setString(
        _historyKey,
        json.encode({
          "messages": clean,
          "scenarioId": _scenario?.id,
          "initialContext": _initialContext,
        }),
      );
    } catch (_) {}
  }

  void _restoreHistory() {
    try {
      final raw = prefs.getString(_historyKey);
      if (raw == null || raw.isEmpty) return;
      final data = json.decode(raw) as Map<String, dynamic>;
      final messagesJson = data["messages"] as List?;
      if (messagesJson == null || messagesJson.isEmpty) return;
      _messages.addAll(
        messagesJson.map(
          (m) => ChatMessage.fromJson(m as Map<String, dynamic>),
        ),
      );
      final scenarioId = data["scenarioId"] as String?;
      if (scenarioId != null) {
        final manager = ChatScenarioManager();
        for (final s in manager.allScenarios) {
          if (s.id == scenarioId) {
            _scenario = s;
            break;
          }
        }
      }
      // Restore the word context so follow-up questions still refer
      // to the same word after reopening the chat.
      _initialContext = data["initialContext"] as String?;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _streamGeneration++;
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Write a streaming chunk into the placeholder at [index], unless
  /// the stream's generation is stale (chat cleared / scenario
  /// changed / disposed) or the placeholder is gone.
  bool _writeStreamChunk(int generation, int index, String text) {
    if (_disposed || generation != _streamGeneration) return false;
    if (index < 0 || index >= _messages.length) return false;
    _messages[index] = ChatMessage(text: text, isUser: false);
    notifyListeners();
    return true;
  }

  List<ChatMessage> get messages => _messages;

  void clearChat() {
    _streamGeneration++;
    _isStreaming = false;
    _messages.clear();
    _scenario = null;
    _persistHistory();
    _notify();
  }

  /// Start a roleplay scenario. Clears current chat.
  void startScenario(ChatScenario scenario) {
    _streamGeneration++;
    _isStreaming = false;
    _messages.clear();
    _scenario = scenario;
    _notify();
    // Send an opening message from the AI.
    _sendScenarioOpener();
  }

  String _buildScenarioSystemPrompt() {
    final template = AIPrompts().scenarioPrompt;
    return template
        .replaceAll(r"$scenarioTitle", _scenario!.promptTitle)
        .replaceAll(r"$scenarioDescription", _scenario!.systemPrompt);
  }

  Future<void> _sendScenarioOpener() async {
    final generation = _streamGeneration;
    _messages.add(const ChatMessage(text: "", isUser: false));
    final index = _messages.length - 1;
    _isStreaming = true;
    _notify();

    final systemPrompt = _buildScenarioSystemPrompt();

    final buffer = StringBuffer();
    try {
      await for (final chunk in _ai.requestStreamWithHistory(
        "Start the roleplay. Greet the user and set the scene in one or two sentences.",
        history: [ChatTurn.system(systemPrompt)],
      )) {
        buffer.write(chunk);
        if (!_writeStreamChunk(generation, index, buffer.toString())) return;
      }
    } catch (e) {
      _writeStreamChunk(generation, index, "Error: $e");
    } finally {
      if (generation == _streamGeneration) {
        _isStreaming = false;
        _persistHistory();
        _notify();
      }
    }
  }

  /// Extract vocabulary words from a message using AI.
  /// Returns a list of words worth learning.
  Future<List<String>> extractVocabulary(String messageText) async {
    final count = prefs.getInt("vocabularyExtractCount") ?? 10;
    final difficulty =
        prefs.getString("vocabularyDifficulty") ??
        "uncommon, academic, or idiomatic";

    final template = AIPrompts().vocabularyPrompt;
    final prompt = template
        .replaceAll(r"$count", count.toString())
        .replaceAll(r"$difficulty", difficulty)
        .replaceAll(r"$text", messageText);

    try {
      final response = await _ai.request(prompt);
      var jsonStr = response.trim();
      if (jsonStr.startsWith("```")) {
        final start = jsonStr.indexOf("\n") + 1;
        final end = jsonStr.lastIndexOf("```");
        jsonStr = jsonStr.substring(start, end).trim();
      }
      final list = json.decode(jsonStr) as List;
      // Materialize eagerly: AI output often drifts from plain
      // strings ({"word": ...} objects, numbers). A lazy cast would
      // throw later, inside the dialog's build.
      return [
        for (final e in list)
          if (e is String && e.trim().isNotEmpty)
            e.trim()
          else if (e is Map && e["word"] != null)
            e["word"].toString(),
      ];
    } catch (e) {
      return [];
    }
  }

  /// Save a word to the wordbook.
  Future<bool> saveWordToWordbook(String word) async {
    try {
      final dao = WordbookDao(mainDatabase);
      await dao.addWord(word);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> sendMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty || _isStreaming) {
      return;
    }

    final generation = _streamGeneration;
    textController.clear();
    _messages.add(ChatMessage(text: text, isUser: true));
    // Placeholder for the streaming AI response.
    _messages.add(ChatMessage(text: "", isUser: false));
    final index = _messages.length - 1;
    _isStreaming = true;
    notifyListeners();

    // Build history from prior turns (excluding the placeholder).
    // If there's initial context (e.g. a word), prepend it as a system hint.
    // If in a scenario, prepend the scenario system prompt from the template.
    final history = [
      if (_scenario != null) ChatTurn.system(_buildScenarioSystemPrompt()),
      for (final m in _messages.sublist(0, _messages.length - 2))
        ChatTurn(m.text, m.isUser),
    ];

    final effectivePrompt = _initialContext != null && history.isEmpty
        ? "The user is asking about the word \"$_initialContext\".\n\n$text"
        : text;

    final buffer = StringBuffer();
    try {
      await for (final chunk in _ai.requestStreamWithHistory(
        effectivePrompt,
        history: history,
      )) {
        buffer.write(chunk);
        if (!_writeStreamChunk(generation, index, buffer.toString())) return;
      }
    } catch (e) {
      _writeStreamChunk(generation, index, "Error: $e");
    } finally {
      if (generation == _streamGeneration) {
        _isStreaming = false;
        _persistHistory();
        _notify();
      }
    }
  }
}

import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:material_ui/material_ui.dart";

class ChatMessage {
  final String text;
  final bool isUser;

  const ChatMessage({required this.text, required this.isUser});
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

  static const List<ChatScenario> presets = [
    ChatScenario(
      id: "restaurant",
      titleKey: "scenarioRestaurant",
      systemPrompt:
          "You are a waiter at a restaurant. Roleplay a dining scenario with the user to help them practice ordering food and conversing in a restaurant. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "travel",
      titleKey: "scenarioTravel",
      systemPrompt:
          "You are a friendly local tour guide. Roleplay a travel scenario with the user to help them practice asking for directions, booking hotels, and sightseeing conversations. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "business",
      titleKey: "scenarioBusiness",
      systemPrompt:
          "You are a business colleague. Roleplay a workplace scenario with the user to help them practice meetings, emails, and professional small talk. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "shopping",
      titleKey: "scenarioShopping",
      systemPrompt:
          "You are a shop assistant. Roleplay a shopping scenario with the user to help them practice asking about prices, sizes, and making purchases. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "daily",
      titleKey: "scenarioDaily",
      systemPrompt:
          "You are a friendly language partner. Have a casual daily conversation with the user to help them practice everyday speaking. Gently correct their language mistakes and suggest more natural expressions.",
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

  /// Optional initial context, e.g. the word from the word detail page.
  final String? initialContext;

  /// Active scenario for roleplay, null for free chat.
  ChatScenario? _scenario;
  ChatScenario? get scenario => _scenario;

  ChatViewModel({this.initialContext}) {
    final config = settings.getAiProviderConfig(settings.aiProvider);
    _ai = AI(
      provider: settings.aiProvider,
      model: config["model"] ?? "",
      apikey: config["apiKey"] ?? "",
    );
  }

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  List<ChatMessage> get messages => _messages;

  void clearChat() {
    _messages.clear();
    _scenario = null;
    notifyListeners();
  }

  /// Start a roleplay scenario. Clears current chat.
  void startScenario(ChatScenario scenario) {
    _messages.clear();
    _scenario = scenario;
    notifyListeners();
    // Send an opening message from the AI.
    _sendScenarioOpener();
  }

  Future<void> _sendScenarioOpener() async {
    _messages.add(const ChatMessage(text: "", isUser: false));
    _isStreaming = true;
    notifyListeners();

    // Build the system prompt from the customizable template.
    final template = AIPrompts().scenarioPrompt;
    final systemPrompt = template
        .replaceAll(r"$scenarioTitle", _scenario!.titleKey)
        .replaceAll(r"$scenarioDescription", _scenario!.systemPrompt);

    final buffer = StringBuffer();
    try {
      await for (final chunk in _ai.requestStreamWithHistory(
        "Start the roleplay. Greet the user and set the scene in one or two sentences.",
        history: [ChatTurn(systemPrompt, false)],
      )) {
        buffer.write(chunk);
        _messages[_messages.length - 1] = ChatMessage(
          text: buffer.toString(),
          isUser: false,
        );
        notifyListeners();
      }
    } catch (e) {
      _messages[_messages.length - 1] = ChatMessage(
        text: "Error: $e",
        isUser: false,
      );
    } finally {
      _isStreaming = false;
      notifyListeners();
    }
  }

  /// Extract vocabulary words from a message using AI.
  /// Returns a list of words worth learning.
  Future<List<String>> extractVocabulary(String messageText) async {
    final count = prefs.getInt("vocabularyExtractCount") ?? 10;
    final difficulty = prefs.getString("vocabularyDifficulty") ?? "uncommon, academic, or idiomatic";

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
      return list.cast<String>();
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

    textController.clear();
    _messages.add(ChatMessage(text: text, isUser: true));
    // Placeholder for the streaming AI response.
    _messages.add(ChatMessage(text: "", isUser: false));
    _isStreaming = true;
    notifyListeners();

    // Build history from prior turns (excluding the placeholder).
    // If there's initial context (e.g. a word), prepend it as a system hint.
    // If in a scenario, prepend the scenario system prompt from the template.
    String? scenarioSystemPrompt;
    if (_scenario != null) {
      final template = AIPrompts().scenarioPrompt;
      scenarioSystemPrompt = template
          .replaceAll(r"$scenarioTitle", _scenario!.titleKey)
          .replaceAll(r"$scenarioDescription", _scenario!.systemPrompt);
    }
    final history = [
      if (scenarioSystemPrompt != null) ChatTurn(scenarioSystemPrompt, false),
      for (final m in _messages.sublist(0, _messages.length - 2))
        ChatTurn(m.text, m.isUser),
    ];

    final effectivePrompt = initialContext != null && history.isEmpty
        ? "The user is asking about the word \"$initialContext\".\n\n$text"
        : text;

    final buffer = StringBuffer();
    try {
      await for (final chunk in _ai.requestStreamWithHistory(
        effectivePrompt,
        history: history,
      )) {
        buffer.write(chunk);
        _messages[_messages.length - 1] = ChatMessage(
          text: buffer.toString(),
          isUser: false,
        );
        notifyListeners();
      }
    } catch (e) {
      _messages[_messages.length - 1] = ChatMessage(
        text: "Error: $e",
        isUser: false,
      );
    } finally {
      _isStreaming = false;
      notifyListeners();
    }
  }
}

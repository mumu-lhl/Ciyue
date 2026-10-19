import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:material_ui/material_ui.dart";

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
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
    notifyListeners();
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
    final history = [
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

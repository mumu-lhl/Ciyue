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

  ChatViewModel() {
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

  Future<void> sendMessage() async {
    final text = textController.text;
    if (text.isEmpty) {
      return;
    }

    textController.clear();
    _messages.add(ChatMessage(text: text, isUser: true));
    // Placeholder for the streaming AI response.
    _messages.add(ChatMessage(text: "", isUser: false));
    notifyListeners();

    // Build history from prior turns (excluding the placeholder).
    final history = [
      for (final m in _messages.sublist(0, _messages.length - 2))
        ChatTurn(m.text, m.isUser),
    ];

    final buffer = StringBuffer();
    try {
      await for (final chunk
          in _ai.requestStreamWithHistory(text, history: history)) {
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
      notifyListeners();
    }
  }
}

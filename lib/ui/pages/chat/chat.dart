import "package:ciyue/viewModels/chat_view_model.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatViewModel(),
      child: const ChatView(),
    );
  }
}

class ChatView extends StatelessWidget {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ChatViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Chat"),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: model.messages.length,
                  itemBuilder: (context, index) {
                    final message = model.messages[index];
                    return ChatBubble(
                      message: message.text,
                      isUser: message.isUser,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Focus(
                  focusNode: model.focusNode,
                  onKeyEvent: (node, event) {
                    if (event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isControlPressed) {
                      if (event is KeyDownEvent) {
                        context.read<ChatViewModel>().sendMessage();
                      }
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    onSubmitted: (_) {
                      context.read<ChatViewModel>().sendMessage();
                    },
                    controller: model.textController,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () {
                            context.read<ChatViewModel>().sendMessage();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * 0.7,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                message,
                style: TextStyle(
                  color: isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

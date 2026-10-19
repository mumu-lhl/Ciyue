import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/chat_view_model.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "dart:math" as math;

class ChatPage extends StatefulWidget {
  final String? initialContext;

  const ChatPage({super.key, this.initialContext});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatViewModel _viewModel;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = ChatViewModel(initialContext: widget.initialContext);
    _viewModel.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_scrollToBottom);
    _viewModel.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isLargeScreen(context);
    final locale = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final model = _viewModel;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.initialContext != null
                  ? "${locale.aiChat} - ${widget.initialContext}"
                  : locale.aiChat,
            ),
            actions: [
              if (model.messages.isNotEmpty)
                IconButton(
                  tooltip: locale.clearChat,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: model.clearChat,
                ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 800 : 600),
              child: Column(
                children: [
                  Expanded(
                    child: model.messages.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount:
                                model.messages.length +
                                (model.isStreaming ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == model.messages.length) {
                                return const _TypingIndicator();
                              }
                              final message = model.messages[index];
                              // Skip empty placeholder while streaming
                              if (!message.isUser &&
                                  message.text.isEmpty &&
                                  model.isStreaming) {
                                return const SizedBox.shrink();
                              }
                              return ChatBubble(
                                message: message.text,
                                isUser: message.isUser,
                              );
                            },
                          ),
                  ),
                  _buildInputArea(context, model),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            widget.initialContext != null
                ? locale.askAboutWord(widget.initialContext!)
                : locale.startConversation,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ChatViewModel model) {
    final locale = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Focus(
          focusNode: model.focusNode,
          onKeyEvent: (node, event) {
            if (event.logicalKey == LogicalKeyboardKey.enter &&
                !HardwareKeyboard.instance.isControlPressed &&
                !HardwareKeyboard.instance.isShiftPressed) {
              if (event is KeyDownEvent) {
                model.sendMessage();
              }
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            onSubmitted: (_) => model.sendMessage(),
            controller: model.textController,
            maxLines: null,
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(
              hintText: locale.typeMessage,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24.0),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: IconButton(
                  icon: model.isStreaming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: model.isStreaming ? null : model.sendMessage,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final delay = index * 0.2;
                final value = (_controller.value - delay).clamp(0.0, 1.0);
                final opacity = (0.3 + 0.7 * (0.5 + 0.5 * math.sin(value * 6.28)))
                    .clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const ChatBubble({super.key, required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUser)
                SelectableText(
                  message,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    height: 1.4,
                  ),
                )
              else
                SelectionArea(
                  child: GptMarkdown(
                    message,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
              if (!isUser && message.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.copied,
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

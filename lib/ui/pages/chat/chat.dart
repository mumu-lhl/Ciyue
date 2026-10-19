import "package:ciyue/repositories/chat_scenarios.dart";
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
              model.scenario != null
                  ? _scenarioTitle(context, model.scenario!)
                  : widget.initialContext != null
                  ? "${locale.aiChat} - ${widget.initialContext}"
                  : locale.aiChat,
            ),
            actions: [
              if (model.scenario != null)
                IconButton(
                  tooltip: locale.exitScenario,
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: model.clearChat,
                ),
              if (model.messages.isNotEmpty && model.scenario == null)
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
                                onExtractVocabulary: model.extractVocabulary,
                                onSaveWord: model.saveWordToWordbook,
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
    final scenarioManager = ChatScenarioManager();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                locale.chooseScenario,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                iconSize: 18,
                icon: const Icon(Icons.settings_outlined),
                tooltip: locale.manageScenarios,
                onPressed: () => _showScenarioManager(context, scenarioManager),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: scenarioManager,
            builder: (context, _) => Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final scenario in scenarioManager.allScenarios)
                  ActionChip(
                    avatar: Icon(
                      _scenarioIcon(scenario.id),
                      size: 18,
                    ),
                    label: Text(_scenarioTitle(context, scenario)),
                    onPressed: () => _viewModel.startScenario(scenario),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _scenarioIcon(String id) {
    switch (id) {
      case "restaurant":
        return Icons.restaurant;
      case "travel":
        return Icons.flight;
      case "business":
        return Icons.business_center;
      case "shopping":
        return Icons.shopping_bag;
      default:
        return Icons.chat;
    }
  }

  String _scenarioTitle(BuildContext context, ChatScenario scenario) {
    // Custom scenarios store the actual title in titleKey.
    if (scenario.id.startsWith("custom_")) {
      return scenario.titleKey;
    }
    final locale = AppLocalizations.of(context)!;
    switch (scenario.id) {
      case "restaurant":
        return locale.scenarioRestaurant;
      case "travel":
        return locale.scenarioTravel;
      case "business":
        return locale.scenarioBusiness;
      case "shopping":
        return locale.scenarioShopping;
      default:
        return locale.scenarioDaily;
    }
  }

  void _showScenarioManager(
    BuildContext context,
    ChatScenarioManager manager,
  ) {
    showDialog(
      context: context,
      builder: (context) => _ScenarioManagerDialog(manager: manager),
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
  final Future<List<String>> Function(String)? onExtractVocabulary;
  final Future<bool> Function(String)? onSaveWord;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.onExtractVocabulary,
    this.onSaveWord,
  });

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      tooltip: "Extract vocabulary",
                      icon: const Icon(Icons.school_outlined),
                      onPressed: () {
                        if (onExtractVocabulary != null &&
                            onSaveWord != null) {
                          _showVocabularyDialog(
                            context,
                            message,
                            onExtractVocabulary!,
                            onSaveWord!,
                          );
                        }
                      },
                    ),
                    IconButton(
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
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showVocabularyDialog(
  BuildContext context,
  String message,
  Future<List<String>> Function(String) onExtract,
  Future<bool> Function(String) onSave,
) {
  showDialog(
    context: context,
    builder: (context) => _VocabularyDialog(
      message: message,
      onExtract: onExtract,
      onSave: onSave,
    ),
  );
}

class _VocabularyDialog extends StatefulWidget {
  final String message;
  final Future<List<String>> Function(String) onExtract;
  final Future<bool> Function(String) onSave;

  const _VocabularyDialog({
    required this.message,
    required this.onExtract,
    required this.onSave,
  });

  @override
  State<_VocabularyDialog> createState() => _VocabularyDialogState();
}

class _VocabularyDialogState extends State<_VocabularyDialog> {
  List<String>? _words;
  final Set<String> _saved = {};

  @override
  void initState() {
    super.initState();
    widget.onExtract(widget.message).then((words) {
      if (mounted) {
        setState(() => _words = words);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(locale.extractVocabulary),
      content: SizedBox(
        width: double.maxFinite,
        child: _words == null
            ? const Center(child: CircularProgressIndicator())
            : _words!.isEmpty
            ? Text(locale.noVocabularyFound)
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final word in _words!)
                    FilterChip(
                      label: Text(word),
                      selected: _saved.contains(word),
                      onSelected: (selected) async {
                        if (selected) {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await widget.onSave(word);
                          if (ok && mounted) {
                            setState(() => _saved.add(word));
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(locale.savedToWordbook),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(locale.close),
        ),
      ],
    );
  }
}

class _ScenarioManagerDialog extends StatelessWidget {
  final ChatScenarioManager manager;

  const _ScenarioManagerDialog({required this.manager});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(locale.manageScenarios),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListenableBuilder(
          listenable: manager,
          builder: (context, _) => ListView(
            children: [
              Text(
                locale.presetScenarios,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final s in ChatScenario.presets)
                SwitchListTile(
                  title: Text(_presetTitle(context, s)),
                  value: !manager.isPresetDisabled(s.id),
                  onChanged: (v) => manager.setPresetDisabled(s.id, !v),
                ),
              const Divider(),
              Text(
                locale.customScenarios,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final s in manager.customScenarios)
                ListTile(
                  title: Text(s.titleKey),
                  subtitle: Text(
                    s.systemPrompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditDialog(context, manager, s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => manager.deleteScenario(s.id),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _showEditDialog(context, manager, null),
          child: Text(locale.addScenario),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(locale.close),
        ),
      ],
    );
  }

  String _presetTitle(BuildContext context, ChatScenario s) {
    final locale = AppLocalizations.of(context)!;
    switch (s.id) {
      case "restaurant":
        return locale.scenarioRestaurant;
      case "travel":
        return locale.scenarioTravel;
      case "business":
        return locale.scenarioBusiness;
      case "shopping":
        return locale.scenarioShopping;
      default:
        return locale.scenarioDaily;
    }
  }

  void _showEditDialog(
    BuildContext context,
    ChatScenarioManager manager,
    ChatScenario? existing,
  ) {
    final titleController = TextEditingController(text: existing?.titleKey ?? "");
    final descController = TextEditingController(
      text: existing?.systemPrompt ?? "",
    );
    final locale = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null ? locale.addScenario : locale.editScenario,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: locale.scenarioTitle),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: locale.scenarioDescription,
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(locale.close),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              final desc = descController.text.trim();
              if (title.isNotEmpty && desc.isNotEmpty) {
                if (existing == null) {
                  manager.addScenario(title, desc);
                } else {
                  manager.updateScenario(existing.id, title, desc);
                }
                Navigator.pop(context);
              }
            },
            child: Text(locale.save),
          ),
        ],
      ),
    );
  }
}

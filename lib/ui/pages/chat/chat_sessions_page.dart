import "package:ciyue/repositories/chat_scenarios.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/chat_view_model.dart";
import "package:material_ui/material_ui.dart";

/// The list of chat sessions: switch between conversations, start
/// a new one, or delete old ones. Before this page existed the app
/// kept exactly one conversation, which could only be resumed or
/// wiped entirely.
class ChatSessionsPage extends StatelessWidget {
  const ChatSessionsPage({super.key, required this.viewModel});

  final ChatViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(locale.chatHistory),
        actions: [
          IconButton(
            tooltip: locale.newChat,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () {
              viewModel.newSession();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) {
              final sessions = viewModel.sessions;
              return ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final isActive = session.id == viewModel.activeSessionId;
                  return ListTile(
                    leading: Icon(
                      isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(
                      _sessionTitle(context, session),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isActive
                          ? const TextStyle(fontWeight: FontWeight.bold)
                          : null,
                    ),
                    subtitle: Text(
                      "${locale.messageCount(session.messages.length)}"
                      " · ${_formatTime(session.updatedAt)}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => viewModel.deleteSession(session.id),
                    ),
                    onTap: () {
                      viewModel.switchSession(session.id);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _sessionTitle(BuildContext context, ChatSession session) {
    final locale = AppLocalizations.of(context)!;
    final derived = session.displayTitle;
    if (derived.isNotEmpty) return derived;
    final scenarioId = session.scenarioId;
    if (scenarioId != null) {
      for (final s in ChatScenarioManager().allScenarios) {
        if (s.id == scenarioId) return _scenarioTitle(context, s);
      }
    }
    if (session.messages.any((m) => m.imagePaths.isNotEmpty)) {
      return locale.imageMessage;
    }
    return locale.newChat;
  }

  /// Same preset-title resolution as the chat page: custom
  /// scenarios store their real title, presets store an l10n key.
  String _scenarioTitle(BuildContext context, ChatScenario scenario) {
    if (scenario.id.startsWith("custom_")) {
      return scenario.titleKey;
    }
    final locale = AppLocalizations.of(context)!;
    return switch (scenario.id) {
      "restaurant" => locale.scenarioRestaurant,
      "travel" => locale.scenarioTravel,
      "business" => locale.scenarioBusiness,
      "shopping" => locale.scenarioShopping,
      _ => locale.scenarioDaily,
    };
  }

  String _formatTime(int milliseconds) {
    final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    String two(int v) => v.toString().padLeft(2, "0");
    return "${time.year}-${two(time.month)}-${two(time.day)} "
        "${two(time.hour)}:${two(time.minute)}";
  }
}

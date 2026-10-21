import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/title_text.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "prompt_editor_page.dart";

/// Localized display title for a prompt definition.
String promptTitle(AppLocalizations locale, AiPromptDefinition definition) {
  return switch (definition.id) {
    "explain" => locale.aiExplainWordPrompt,
    "translate" => locale.aiTranslatePrompt,
    "writingCheck" => locale.writingCheckPromptTitle,
    "quiz" => locale.quizPromptTitle,
    "vocabulary" => locale.vocabularyPromptTitle,
    "scenario" => locale.scenarioPromptTitle,
    _ => definition.id,
  };
}

/// Localized helper text (purpose + variables) for a prompt definition.
String promptHelper(AppLocalizations locale, AiPromptDefinition definition) {
  return switch (definition.id) {
    "explain" => locale.customExplainPromptHelper,
    "translate" => locale.customTranslatePromptHelper,
    "writingCheck" => locale.writingCheckPromptHelper,
    "quiz" => locale.quizPromptHelper,
    "vocabulary" => locale.vocabularyPromptHelper,
    "scenario" => locale.scenarioPromptHelper,
    _ => "",
  };
}

/// Overview of all customizable prompts: which ones were changed
/// from their defaults, a preview of each, and one-tap access to
/// the full-screen editor. Replaces the six inline editors that
/// used to be stacked inside AI Settings.
class AiPromptsPage extends ConsumerWidget {
  const AiPromptsPage({super.key});

  static const _wordGroup = [
    AIPrompts.explainDefinition,
    AIPrompts.translateDefinition,
    AIPrompts.writingCheckDefinition,
  ];
  static const _learningGroup = [
    AIPrompts.quizDefinition,
    AIPrompts.vocabularyDefinition,
    AIPrompts.scenarioDefinition,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final prompts = ref.watch(aiPromptsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(locale.promptManagement),
        actions: [
          if (prompts.customizedCount > 0)
            IconButton(
              tooltip: locale.resetAllPrompts,
              icon: const Icon(Icons.restart_alt),
              onPressed: () => _confirmResetAll(context, prompts),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500.0),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              TitleText(locale.promptsGroupWord),
              const SizedBox(height: 6),
              for (final definition in _wordGroup)
                _PromptTile(definition: definition, prompts: prompts),
              const SizedBox(height: 24),
              TitleText(locale.promptsGroupLearning),
              const SizedBox(height: 6),
              for (final definition in _learningGroup)
                _PromptTile(definition: definition, prompts: prompts),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmResetAll(BuildContext context, AIPrompts prompts) async {
    final locale = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locale.resetAllPrompts),
        content: Text(locale.resetAllPromptsConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(locale.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(locale.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await prompts.resetAllPrompts();
    }
  }
}

class _PromptTile extends StatelessWidget {
  const _PromptTile({required this.definition, required this.prompts});

  final AiPromptDefinition definition;
  final AIPrompts prompts;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final customized = prompts.isCustomized(definition);
    final text = prompts.promptFor(definition);
    final preview = text
        .split("\n")
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => "");
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(promptTitle(locale, definition)),
        subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: customized
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                customized ? locale.promptCustomized : locale.promptIsDefault,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: customized
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PromptEditorPage(definition: definition),
            ),
          );
        },
      ),
    );
  }
}

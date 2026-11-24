import "dart:async";

import "package:ciyue/core/providers.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/e_ink.dart";
import "package:ciyue/ui/core/language_names.dart";
import "package:ciyue/ui/core/language_picker.dart";
import "package:ciyue/ui/core/word_display/ai_explanation_view.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "package:gpt_markdown/gpt_markdown.dart";

class AIExplainView extends ConsumerStatefulWidget {
  final String word;

  const AIExplainView({super.key, required this.word});

  @override
  ConsumerState<AIExplainView> createState() => _AIExplainViewState();
}

class _AIExplainViewState extends ConsumerState<AIExplainView> {
  void _requestExplanation({bool manual = false}) {
    if (!manual &&
        !shouldAutoRequestAiExplanation(ref.read(settingsProvider))) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(
              aiExplanationModelProvider((
                word: widget.word,
                sourceLanguage: ref.read(
                  aiExplanationSourceLanguageProvider(widget.word),
                ),
              )),
            )
            .getExplanation(widget.word),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _requestExplanation();
  }

  @override
  void didUpdateWidget(covariant AIExplainView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.word != oldWidget.word) {
      _requestExplanation();
    }
  }

  Widget _sourceLanguageChip(BuildContext context, String sourceLanguage) {
    final l10n = AppLocalizations.of(context)!;
    return ActionChip(
      label: Text(localizedLanguageName(sourceLanguage, l10n)),
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.85,
          child: LanguagePicker(
            selectedLanguage: sourceLanguage,
            isSource: true,
            onLanguageSelected: (code) {
              ref
                      .read(
                        aiExplanationSourceLanguageOverrideProvider(widget.word)
                            .notifier,
                      )
                      .state =
                  code;
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manual = ref.watch(
      settingsProvider.select((settings) => settings.aiExplainWordManual),
    );
    final sourceLanguage = ref.watch(
      aiExplanationSourceLanguageProvider(widget.word),
    );
    ref.listen(aiExplanationSourceLanguageProvider(widget.word), (_, _) {
      _requestExplanation();
    });
    final model = ref.watch(
      aiExplanationModelProvider((
        word: widget.word,
        sourceLanguage: sourceLanguage,
      )),
    );
    final localizations = AppLocalizations.of(context)!;
    final chip = _sourceLanguageChip(context, sourceLanguage);
    if (manual && !model.isLoading && model.explanation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              chip,
              const SizedBox(height: 16),
              Text(
                localizations.aiExplainWordManualDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _requestExplanation(manual: true),
                icon: const Icon(Icons.auto_awesome),
                label: Text(localizations.requestAIExplanation),
              ),
            ],
          ),
        ),
      );
    }
    if (model.isLoading || model.explanation == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip,
            const SizedBox(height: 16),
            const EInkAwareSpinner(),
          ],
        ),
      );
    }
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                chip,
                const SizedBox(height: 12),
                model.structured != null
                    ? AiExplanationView(data: model.structured!)
                    : SelectionArea(child: GptMarkdown(model.explanation!)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RefreshAIExplainButton extends ConsumerWidget {
  final String word;

  const RefreshAIExplainButton({super.key, required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final sourceLanguage = ref.watch(aiExplanationSourceLanguageProvider(word));

    return FloatingActionButton.small(
      heroTag: "refresh_ai_explain_$word",
      tooltip: AppLocalizations.of(context)!.update,
      foregroundColor: colorScheme.primary,
      backgroundColor: colorScheme.primaryContainer,
      child: const Icon(Icons.refresh),
      onPressed: () {
        unawaited(
          ref
              .read(
                aiExplanationModelProvider((
                  word: word,
                  sourceLanguage: sourceLanguage,
                )),
              )
              .refreshExplanation(word),
        );
      },
    );
  }
}

class EditAIExplainButton extends ConsumerWidget {
  final String word;
  final String initialExplanation;

  const EditAIExplainButton({
    super.key,
    required this.word,
    required this.initialExplanation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final sourceLanguage = ref.watch(aiExplanationSourceLanguageProvider(word));

    return FloatingActionButton.small(
      heroTag: "edit_ai_explain_$word",
      tooltip: AppLocalizations.of(context)!.editAIExplanation,
      foregroundColor: colorScheme.primary,
      backgroundColor: colorScheme.primaryContainer,
      child: const Icon(Icons.edit),
      onPressed: () {
        unawaited(
          context.push(
            "/edit_ai_explanation",
            extra: {
              "word": word,
              "initialExplanation": initialExplanation,
              "aiExplanationModel": ref.read(
                aiExplanationModelProvider((
                  word: word,
                  sourceLanguage: sourceLanguage,
                )),
              ),
            },
          ),
        );
      },
    );
  }
}

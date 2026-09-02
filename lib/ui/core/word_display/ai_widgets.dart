import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/ai_explanation.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:provider/provider.dart";

class AIExplainView extends StatefulWidget {
  final String word;

  const AIExplainView({super.key, required this.word});

  @override
  State<AIExplainView> createState() => _AIExplainViewState();
}

class _AIExplainViewState extends State<AIExplainView> {
  void _requestExplanation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AIExplanationModel>().getExplanation(widget.word);
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AIExplanationModel>(
      builder: (context, model, child) {
        if (model.isLoading || model.explanation == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectionArea(child: GptMarkdown(model.explanation!)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class RefreshAIExplainButton extends StatelessWidget {
  final String word;

  const RefreshAIExplainButton({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.small(
      heroTag: "refresh_ai_explain_$word",
      tooltip: AppLocalizations.of(context)!.update,
      foregroundColor: colorScheme.primary,
      backgroundColor: colorScheme.primaryContainer,
      child: const Icon(Icons.refresh),
      onPressed: () {
        context.read<AIExplanationModel>().refreshExplanation(word);
      },
    );
  }
}

class EditAIExplainButton extends StatelessWidget {
  final String word;
  final String initialExplanation;

  const EditAIExplainButton({
    super.key,
    required this.word,
    required this.initialExplanation,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.small(
      heroTag: "edit_ai_explain_$word",
      tooltip: AppLocalizations.of(context)!.editAIExplanation,
      foregroundColor: colorScheme.primary,
      backgroundColor: colorScheme.primaryContainer,
      child: const Icon(Icons.edit),
      onPressed: () {
        context.push(
          "/edit_ai_explanation",
          extra: {
            "word": word,
            "initialExplanation": initialExplanation,
            "aiExplanationModel": context.read<AIExplanationModel>(),
          },
        );
      },
    );
  }
}

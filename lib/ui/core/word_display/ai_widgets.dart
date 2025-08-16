import "package:ciyue/viewModels/ai_explanation.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:provider/provider.dart";

class AIExplainView extends StatelessWidget {
  final String word;

  const AIExplainView({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AIExplanationModel>().getExplanation(word);
    });

    return Consumer<AIExplanationModel>(
      builder: (context, model, child) {
        if (model.isLoading || model.explanation == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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

  const RefreshAIExplainButton({
    super.key,
    required this.word,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.small(
      heroTag: "refresh_ai_explain_$word",
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

import "package:ciyue/models/ai_explanation_data.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";

/// Renders a structured AI word explanation with the app theme —
/// phonetic and part of speech up top, then numbered meanings,
/// example sentences with translations, and synonym/antonym chips —
/// instead of a markdown document.
class AiExplanationView extends StatelessWidget {
  const AiExplanationView({super.key, required this.data});

  final AiExplanationData data;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final children = <Widget>[];

    if (data.phonetic != null || data.partOfSpeech != null) {
      children.add(
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (data.phonetic != null)
              Text(
                data.phonetic!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (data.partOfSpeech != null) _chip(context, data.partOfSpeech!),
          ],
        ),
      );
    }

    if (data.meanings.isNotEmpty) {
      children.add(
        _section(
          context,
          localizations.aiExplanationMeanings,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < data.meanings.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          "${i + 1}.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          data.meanings[i],
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (data.examples.isNotEmpty) {
      children.add(
        _section(
          context,
          localizations.aiExplanationExamples,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < data.examples.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Text(
                    data.examples[i].sentence,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (data.examples[i].translation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        data.examples[i].translation!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (data.synonyms.isNotEmpty) {
      children.add(
        _chipSection(
          context,
          localizations.aiExplanationSynonyms,
          data.synonyms,
        ),
      );
    }
    if (data.antonyms.isNotEmpty) {
      children.add(
        _chipSection(
          context,
          localizations.aiExplanationAntonyms,
          data.antonyms,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          children[i],
        ],
      ],
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _chipSection(BuildContext context, String title, List<String> words) {
    return _section(
      context,
      title,
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final word in words) _chip(context, word)],
      ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
}

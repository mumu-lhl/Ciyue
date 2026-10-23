import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/title_text.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class ExplainWordSetting extends ConsumerWidget {
  const ExplainWordSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    final explainWord = ref.watch(
      aiSettingsViewModelProvider.select((vm) => vm.explainWord),
    );
    final explainStructured = ref.watch(
      aiSettingsViewModelProvider.select((vm) => vm.explainStructured),
    );
    final viewModel = ref.read(aiSettingsViewModelProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TitleText(localizations.aiExplainWord),
            const Spacer(),
            Switch(value: explainWord, onChanged: viewModel.setExplainWord),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.aiStructuredExplanation,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    localizations.aiStructuredExplanationDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: explainStructured,
              onChanged: explainWord ? viewModel.setExplainStructured : null,
            ),
          ],
        ),
      ],
    );
  }
}

import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/language_names.dart";
import "package:ciyue/ui/core/language_picker.dart";
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
    final explainWordManual = ref.watch(
      aiSettingsViewModelProvider.select((vm) => vm.explainWordManual),
    );
    final sourceLanguageMode = ref.watch(
      aiSettingsViewModelProvider.select((vm) => vm.explainSourceLanguageMode),
    );
    final sourceLanguage = ref.watch(
      aiSettingsViewModelProvider.select((vm) => vm.explainSourceLanguage),
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
                    localizations.aiExplainWordManual,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    localizations.aiExplainWordManualDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: explainWordManual,
              onChanged: explainWord ? viewModel.setExplainWordManual : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          localizations.aiSourceLanguageMode,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: "fixed",
              label: Text(localizations.aiSourceLanguageFixed),
            ),
            ButtonSegment(
              value: "groupName",
              label: Text(localizations.aiSourceLanguageFromGroup),
            ),
          ],
          selected: {sourceLanguageMode},
          onSelectionChanged: (selection) {
            viewModel.setExplainSourceLanguageMode(selection.first);
          },
        ),
        if (sourceLanguageMode == "fixed")
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.sourceLanguage,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
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
                        viewModel.setExplainSourceLanguage(code);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
                child: Text(
                  localizedLanguageName(sourceLanguage, localizations),
                ),
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              localizations.aiSourceLanguageFromGroupDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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

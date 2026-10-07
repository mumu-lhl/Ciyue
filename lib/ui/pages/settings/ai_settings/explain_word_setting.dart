import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/title_text.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class ExplainWordSetting extends ConsumerWidget {
  const ExplainWordSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final explainWord = ref.watch(
      aiSettingsViewModelProvider.select((vm) => vm.explainWord),
    );
    final viewModel = ref.read(aiSettingsViewModelProvider);
    return Row(
      children: [
        TitleText(AppLocalizations.of(context)!.aiExplainWord),
        const Spacer(),
        Switch(value: explainWord, onChanged: viewModel.setExplainWord),
      ],
    );
  }
}

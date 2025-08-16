import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/title_text.dart";
import "package:ciyue/viewModels/ai_settings_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class ExplainWordSetting extends StatelessWidget {
  const ExplainWordSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final explainWord =
        context.select((AISettingsViewModel vm) => vm.explainWord);
    final viewModel = context.read<AISettingsViewModel>();
    return Row(
      children: [
        TitleText(
          AppLocalizations.of(context)!.aiExplainWord,
        ),
        const Spacer(),
        Switch(
          value: explainWord,
          onChanged: viewModel.setExplainWord,
        ),
      ],
    );
  }
}

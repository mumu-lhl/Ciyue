import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/title_text.dart";
import "package:ciyue/viewModels/ai_settings_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class AIAPIUrl extends StatelessWidget {
  const AIAPIUrl({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AISettingsViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleText(
          AppLocalizations.of(context)!.apiUrl,
        ),
        const SizedBox(height: 12),
        TextFormField(
            controller: viewModel.apiUrlController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: AppLocalizations.of(context)!.apiUrl,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: viewModel.setAiAPIUrl),
        const SizedBox(height: 24),
      ],
    );
  }
}

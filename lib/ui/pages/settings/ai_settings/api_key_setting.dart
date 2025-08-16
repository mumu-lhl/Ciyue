import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/ai_settings_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class APIKeySetting extends StatelessWidget {
  const APIKeySetting({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AISettingsViewModel>();
    return TextFormField(
      controller: viewModel.apiKeyController,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: AppLocalizations.of(context)!.apiKey,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: viewModel.setApiKey,
      obscureText: true,
    );
  }
}

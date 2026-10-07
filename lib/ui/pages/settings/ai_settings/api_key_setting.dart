import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class APIKeySetting extends ConsumerWidget {
  const APIKeySetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(aiSettingsViewModelProvider);
    return TextFormField(
      controller: viewModel.apiKeyController,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: AppLocalizations.of(context)!.apiKey,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      onChanged: viewModel.setApiKey,
      obscureText: true,
    );
  }
}

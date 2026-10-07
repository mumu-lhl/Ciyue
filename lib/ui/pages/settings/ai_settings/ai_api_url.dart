import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/title_text.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class AIAPIUrl extends ConsumerWidget {
  const AIAPIUrl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(aiSettingsViewModelProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleText(AppLocalizations.of(context)!.apiUrl),
        const SizedBox(height: 12),
        TextFormField(
          controller: viewModel.apiUrlController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: AppLocalizations.of(context)!.apiUrl,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          onChanged: viewModel.setAiAPIUrl,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

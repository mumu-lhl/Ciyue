import "package:ciyue/core/providers.dart";
import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/ai_settings/selection_modal.dart";
import "package:ciyue/ui/pages/settings/ai_settings/setting_selection_chip.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class ProviderSetting extends ConsumerWidget {
  const ProviderSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(aiSettingsViewModelProvider);
    final providerName = ref.watch(
      aiSettingsViewModelProvider.select((vm) => vm.provider),
    );
    final providers = ModelProviderManager.modelProviders.values.toList();
    final currentProvider = providers.firstWhere(
      (p) => p.name == providerName,
      orElse: () => providers.first,
    );

    return SettingSelectionChip(
      label: currentProvider.displayedName,
      onTap: () {
        showSelectionModal<ModelProvider>(
          context: context,
          title: AppLocalizations.of(context)!.aiProvider,
          items: providers,
          currentItem: currentProvider,
          itemText: (p) => p.displayedName,
          onItemSelected: (p) {
            viewModel.setProvider(p.name);
          },
        );
      },
    );
  }
}

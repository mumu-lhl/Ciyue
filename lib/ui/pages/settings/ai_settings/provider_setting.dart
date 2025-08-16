import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/ai_settings/selection_modal.dart";
import "package:ciyue/ui/pages/settings/ai_settings/setting_selection_chip.dart";
import "package:ciyue/viewModels/ai_settings_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class ProviderSetting extends StatelessWidget {
  const ProviderSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AISettingsViewModel>();
    final providerName =
        context.select((AISettingsViewModel vm) => vm.provider);
    final providers = ModelProviderManager.modelProviders.values.toList();
    final currentProvider = providers.firstWhere((p) => p.name == providerName,
        orElse: () => providers.first);

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

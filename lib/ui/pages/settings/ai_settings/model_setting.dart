import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/ai_settings/selection_modal.dart";
import "package:ciyue/ui/pages/settings/ai_settings/setting_selection_chip.dart";
import "package:ciyue/viewModels/ai_settings_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class ModelSetting extends StatelessWidget {
  const ModelSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AISettingsViewModel>();
    final providerName =
        context.select((AISettingsViewModel vm) => vm.provider);
    final modelName = context.select((AISettingsViewModel vm) => vm.model);

    final currentProvider = ModelProviderManager.modelProviders[providerName] ??
        ModelProviderManager.modelProviders.values.first;

    if (currentProvider.allowCustomModel) {
      return TextFormField(
        controller: viewModel.modelController,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          hintText: AppLocalizations.of(context)!.aiModel,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onChanged: viewModel.setModel,
      );
    } else {
      final currentModels = currentProvider.models;
      final currentModel = currentModels.firstWhere(
        (m) => m.originName == modelName,
        orElse: () => currentModels.first,
      );

      return SettingSelectionChip(
        label: currentModel.shownName,
        onTap: () {
          showSelectionModal<ModelInfo>(
            context: context,
            title: AppLocalizations.of(context)!.aiModel,
            items: currentModels,
            currentItem: currentModel,
            itemText: (m) => m.shownName,
            onItemSelected: (m) {
              viewModel.setModel(m.originName);
            },
          );
        },
      );
    }
  }
}

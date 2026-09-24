import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/ai_settings/selection_modal.dart";
import "package:ciyue/ui/pages/settings/ai_settings/setting_selection_chip.dart";
import "package:ciyue/viewModels/ai_settings_view_model.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

class ModelSetting extends StatelessWidget {
  const ModelSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AISettingsViewModel>();
    final providerName = viewModel.provider;
    final modelName = viewModel.model;

    final currentProvider =
        ModelProviderManager.modelProviders[providerName] ??
        ModelProviderManager.modelProviders.values.first;

    final currentModels = viewModel.currentModels;
    final currentModel = currentModels
        .where((m) => m.originName == modelName)
        .firstOrNull;

    final locale = AppLocalizations.of(context)!;

    void openModelSelection() {
      showSelectionModal<ModelInfo>(
        context: context,
        title: locale.aiModel,
        searchHint: locale.searchModels,
        items: currentModels,
        currentItem: currentModel,
        itemText: (m) => m.shownName == m.originName
            ? m.originName
            : "${m.shownName} (${m.originName})",
        onItemSelected: (m) {
          viewModel.setModel(m.originName);
        },
      );
    }

    Future<void> onFetchModels() async {
      if (viewModel.apiKey.trim().isEmpty &&
          providerName != "ollama" &&
          providerName != "openrouter") {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(locale.apiKeyRequired)));
        return;
      }

      final success = await viewModel.fetchModels();
      if (!context.mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "${locale.fetchModelsSuccess} (${viewModel.currentModels.length})",
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "${locale.fetchModelsFailed}: ${viewModel.fetchError ?? ''}",
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    final syncButton = IconButton(
      icon: viewModel.isFetchingModels
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
      tooltip: locale.fetchModels,
      onPressed: viewModel.isFetchingModels ? null : onFetchModels,
    );

    if (currentProvider.allowCustomModel) {
      return Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: viewModel.modelController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: locale.aiModel,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                suffixIcon: currentModels.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.arrow_drop_down),
                        tooltip: locale.selectModel,
                        onPressed: openModelSelection,
                      )
                    : null,
              ),
              onChanged: viewModel.setModel,
            ),
          ),
          const SizedBox(width: 8),
          syncButton,
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: SettingSelectionChip(
              label:
                  currentModel?.shownName ??
                  (modelName.isNotEmpty ? modelName : locale.aiModel),
              onTap: openModelSelection,
            ),
          ),
          const SizedBox(width: 8),
          syncButton,
        ],
      );
    }
  }
}

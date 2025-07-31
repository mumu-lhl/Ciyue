import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/ai_settings_view_model.dart";
import "package:ciyue/viewModels/home.dart";
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

class AiSettingsPage extends StatelessWidget {
  const AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AISettingsViewModel(
        context.read<AIPrompts>(),
        context.read<HomeModel>(),
      ),
      child: Builder(builder: (context) {
        final viewModel = context.read<AISettingsViewModel>();
        final provider =
            context.select((AISettingsViewModel vm) => vm.provider);
        final explainPrompt = context
            .select((AISettingsViewModel vm) => vm.aiPrompts.explainPrompt);
        final translatePrompt = context
            .select((AISettingsViewModel vm) => vm.aiPrompts.translatePrompt);
        final writingCheckPrompt = context.select(
            (AISettingsViewModel vm) => vm.aiPrompts.writingCheckPrompt);

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.aiSettings),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500.0),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AI Provider
                        TitleText(
                          AppLocalizations.of(context)!.aiProvider,
                        ),
                        const SizedBox(height: 12),
                        const _ProviderSetting(),
                        const SizedBox(height: 24),

                        // AI API URL
                        if (ModelProviderManager
                            .modelProviders[provider]!.allowCustomAPIUrl)
                          const AIAPIUrl(),

                        // AI Model
                        TitleText(
                          AppLocalizations.of(context)!.aiModel,
                        ),
                        const SizedBox(height: 12),
                        const _ModelSetting(),
                        const SizedBox(height: 24),

                        // API Key
                        TitleText(
                          AppLocalizations.of(context)!.apiKey,
                        ),
                        const SizedBox(height: 12),
                        const _APIKeySetting(),
                        const SizedBox(height: 24),

                        // Explain Word
                        const _ExplainWordSetting(),
                        const SizedBox(height: 24),

                        // Explain Word Prompt Setting
                        _PromptSetting(
                          title:
                              AppLocalizations.of(context)!.aiExplainWordPrompt,
                          initialValue: explainPrompt,
                          helperText: AppLocalizations.of(context)!
                              .customExplainPromptHelper,
                          onChanged: viewModel.aiPrompts.setExplainPrompt,
                          onReset: viewModel.aiPrompts.resetExplainPrompt,
                        ),
                        const SizedBox(height: 24),

                        // AI Translate Prompt Setting
                        _PromptSetting(
                          title:
                              AppLocalizations.of(context)!.aiTranslatePrompt,
                          initialValue: translatePrompt,
                          helperText: AppLocalizations.of(context)!
                              .customTranslatePromptHelper,
                          onChanged: viewModel.aiPrompts.setTranslatePrompt,
                          onReset: viewModel.aiPrompts.resetTranslatePrompt,
                        ),
                        const SizedBox(height: 24),

                        // Writing Check Prompt Setting
                        _PromptSetting(
                          title: AppLocalizations.of(context)!
                              .writingCheckPromptTitle,
                          initialValue: writingCheckPrompt,
                          helperText: AppLocalizations.of(context)!
                              .writingCheckPromptHelper,
                          onChanged: viewModel.aiPrompts.setWritingCheckPrompt,
                          onReset: viewModel.aiPrompts.resetWritingCheckPrompt,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class TitleText extends StatelessWidget {
  final String text;

  const TitleText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}

class _PromptSetting extends StatelessWidget {
  const _PromptSetting({
    required this.title,
    required this.initialValue,
    required this.helperText,
    required this.onChanged,
    required this.onReset,
  });

  final String title;
  final String initialValue;
  final String helperText;
  final Future<void> Function(String) onChanged;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleText(title),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(initialValue),
          initialValue: initialValue,
          maxLines: null,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            helperText: helperText,
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onReset,
            child: Text(AppLocalizations.of(context)!.resetToDefault),
          ),
        ),
      ],
    );
  }
}

class _APIKeySetting extends StatelessWidget {
  const _APIKeySetting();

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

class _ExplainWordSetting extends StatelessWidget {
  const _ExplainWordSetting();

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

class _ModelSetting extends StatelessWidget {
  const _ModelSetting();

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

      return _SettingSelectionChip(
        label: currentModel.shownName,
        onTap: () {
          _showSelectionModal<ModelInfo>(
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

class _ProviderSetting extends StatelessWidget {
  const _ProviderSetting();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AISettingsViewModel>();
    final providerName =
        context.select((AISettingsViewModel vm) => vm.provider);
    final providers = ModelProviderManager.modelProviders.values.toList();
    final currentProvider = providers.firstWhere((p) => p.name == providerName,
        orElse: () => providers.first);

    return _SettingSelectionChip(
      label: currentProvider.displayedName,
      onTap: () {
        _showSelectionModal<ModelProvider>(
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

class _SettingSelectionChip extends StatelessWidget {
  const _SettingSelectionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

void _showSelectionModal<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required T currentItem,
  required String Function(T) itemText,
  required void Function(T) onItemSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      widthFactor: 0.9,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(itemText(item)),
                    trailing:
                        item == currentItem ? const Icon(Icons.check) : null,
                    onTap: () {
                      onItemSelected(item);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/repositories/settings.dart";
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
            initialValue: settings.aiAPIUrl,
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
    final apiKey = context.select((AISettingsViewModel vm) => vm.apiKey);
    final viewModel = context.read<AISettingsViewModel>();
    return TextFormField(
      key: ValueKey(apiKey),
      initialValue: apiKey,
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
    final provider = context.select((AISettingsViewModel vm) => vm.provider);
    final model = context.select((AISettingsViewModel vm) => vm.model);
    final viewModel = context.read<AISettingsViewModel>();

    final currentProvider = ModelProviderManager.modelProviders[provider] ??
        ModelProviderManager.modelProviders.values.first;

    if (currentProvider.allowCustomModel) {
      return TextFormField(
        key: ValueKey(provider + model),
        initialValue: model,
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
      return DropdownButtonFormField<String>(
        value: currentModels.any((m) => m.originName == model)
            ? model
            : currentModels[0].originName,
        hint: Text(AppLocalizations.of(context)!.aiModel),
        padding: const EdgeInsets.only(left: 8, right: 8),
        onChanged: (String? newValue) {
          if (newValue != null) {
            viewModel.setModel(newValue);
          }
        },
        items: currentModels.map<DropdownMenuItem<String>>((ModelInfo value) {
          return DropdownMenuItem<String>(
            value: value.originName,
            child: Text(value.shownName),
          );
        }).toList(),
      );
    }
  }
}

class _ProviderSetting extends StatelessWidget {
  const _ProviderSetting();

  @override
  Widget build(BuildContext context) {
    final provider = context.select((AISettingsViewModel vm) => vm.provider);
    final viewModel = context.read<AISettingsViewModel>();
    return DropdownButtonFormField<String>(
      value: provider,
      hint: Text(AppLocalizations.of(context)!.aiProvider),
      padding: const EdgeInsets.only(left: 8, right: 8),
      onChanged: (String? newValue) {
        if (newValue != null) {
          viewModel.setProvider(newValue);
        }
      },
      items: ModelProviderManager.modelProviders.values
          .map<DropdownMenuItem<String>>((ModelProvider p) {
        return DropdownMenuItem<String>(
          value: p.name,
          child: Text(p.displayedName),
        );
      }).toList(),
    );
  }
}

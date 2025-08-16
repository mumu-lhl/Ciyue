import "package:ciyue/services/ai.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/title_text.dart";
import "package:ciyue/ui/pages/settings/ai_settings/ai_api_url.dart";
import "package:ciyue/ui/pages/settings/ai_settings/api_key_setting.dart";
import "package:ciyue/ui/pages/settings/ai_settings/explain_word_setting.dart";
import "package:ciyue/ui/pages/settings/ai_settings/model_setting.dart";
import "package:ciyue/ui/pages/settings/ai_settings/prompt_setting.dart";
import "package:ciyue/ui/pages/settings/ai_settings/provider_setting.dart";
import "package:ciyue/viewModels/ai_settings_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class AiSettingsPage extends StatelessWidget {
  const AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AISettingsViewModel(
        context.read(),
        context.read(),
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
                        const ProviderSetting(),
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
                        const ModelSetting(),
                        const SizedBox(height: 24),

                        // API Key
                        TitleText(
                          AppLocalizations.of(context)!.apiKey,
                        ),
                        const SizedBox(height: 12),
                        const APIKeySetting(),
                        const SizedBox(height: 24),

                        // Explain Word
                        const ExplainWordSetting(),
                        const SizedBox(height: 24),

                        // Explain Word Prompt Setting
                        PromptSetting(
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
                        PromptSetting(
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
                        PromptSetting(
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

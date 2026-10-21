import "package:ciyue/core/providers.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/settings_group.dart";
import "package:ciyue/ui/core/title_text.dart";
import "package:ciyue/ui/pages/settings/ai_settings/ai_api_url.dart";
import "package:ciyue/ui/pages/settings/ai_settings/api_key_setting.dart";
import "package:ciyue/ui/pages/settings/ai_settings/explain_word_setting.dart";
import "package:ciyue/ui/pages/settings/ai_settings/learning_settings.dart";
import "package:ciyue/ui/pages/settings/ai_settings/model_setting.dart";
import "package:ciyue/ui/pages/settings/ai_settings/provider_setting.dart";
import "package:ciyue/viewModels/ai_settings_view_model.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

class AiSettingsPage extends ConsumerWidget {
  const AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(
      aiSettingsViewModelProvider.select(
        (AISettingsViewModel vm) => vm.provider,
      ),
    );
    final customizedPromptCount = ref.watch(
      aiPromptsProvider.select((prompts) => prompts.customizedCount),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.aiSettings)),
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
                    TitleText(AppLocalizations.of(context)!.aiProvider),
                    const SizedBox(height: 6),
                    const SettingsFieldCard(child: ProviderSetting()),
                    const SizedBox(height: 24),

                    // AI API URL
                    if (ModelProviderManager
                        .modelProviders[provider]!
                        .allowCustomAPIUrl)
                      const AIAPIUrl(),

                    // AI Model
                    TitleText(AppLocalizations.of(context)!.aiModel),
                    const SizedBox(height: 6),
                    const SettingsFieldCard(child: ModelSetting()),
                    const SizedBox(height: 24),

                    // API Key
                    TitleText(AppLocalizations.of(context)!.apiKey),
                    const SizedBox(height: 6),
                    const SettingsFieldCard(child: APIKeySetting()),
                    const SizedBox(height: 24),

                    // Explain Word
                    const SettingsFieldCard(child: ExplainWordSetting()),
                    const SizedBox(height: 24),

                    // Prompt Management (dedicated page)
                    SettingsFieldCard(
                      child: ListTile(
                        leading: const Icon(Icons.edit_note_outlined),
                        title: Text(
                          AppLocalizations.of(context)!.promptManagement,
                        ),
                        subtitle: Text(
                          customizedPromptCount > 0
                              ? AppLocalizations.of(
                                  context,
                                )!.customizedPromptsCount(customizedPromptCount)
                              : AppLocalizations.of(context)!.promptsAllDefault,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push("/settings/ai_settings/prompts"),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Learning Settings
                    TitleText(AppLocalizations.of(context)!.learningSettings),
                    const SizedBox(height: 6),
                    const SettingsFieldCard(child: LearningSettings()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

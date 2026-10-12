import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/translate_settings_view_model.dart";
import "package:material_ui/material_ui.dart";

class AiTranslateSettingsPage extends StatefulWidget {
  const AiTranslateSettingsPage({super.key});

  @override
  State<AiTranslateSettingsPage> createState() =>
      _AiTranslateSettingsPageState();
}

class _AiTranslateSettingsPageState extends State<AiTranslateSettingsPage> {
  late final AiTranslateSettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AiTranslateSettingsViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final viewModel = _viewModel;
        return Scaffold(
          appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<bool>(
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!
                                  .outputType,
                              prefixIcon: const Icon(Icons.tune_rounded),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            initialValue: viewModel.isRichOutput,
                            items: [
                              DropdownMenuItem(
                                value: true,
                                child: Text(
                                  AppLocalizations.of(context)!.richOutput,
                                ),
                              ),
                              DropdownMenuItem(
                                value: false,
                                child: Text(
                                  AppLocalizations.of(context)!.simpleOutput,
                                ),
                              ),
                            ],
                            onChanged: (bool? newValue) {
                              if (newValue != null) {
                                viewModel.setRichOutput(newValue);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!
                                  .translationProvider,
                              prefixIcon: const Icon(Icons.hub_outlined),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            initialValue: viewModel.translationProvider,
                            items: const [
                              DropdownMenuItem(value: "ai", child: Text("AI")),
                              DropdownMenuItem(
                                value: "google",
                                child: Text("Google"),
                              ),
                              DropdownMenuItem(
                                value: "deeplx",
                                child: Text("DeepLX"),
                              ),
                            ],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                viewModel.setTranslationProvider(newValue);
                              }
                            },
                          ),
                          if (viewModel.translationProvider == "deeplx") ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: viewModel.deeplxUrlController,
                              decoration: const InputDecoration(
                                labelText: "DeepLX URL",
                                prefixIcon: Icon(Icons.link_rounded),
                              ),
                              onChanged: viewModel.setDeeplxUrl,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      secondary: const Icon(Icons.history_rounded),
                      title: Text(
                        AppLocalizations.of(context)!.enableTranslationHistory,
                      ),
                      value: viewModel.enableTranslationHistory,
                      onChanged: viewModel.setEnableTranslationHistory,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

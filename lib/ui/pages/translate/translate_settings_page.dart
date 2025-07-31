import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/translate_settings_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class AiTranslateSettingsPage extends StatelessWidget {
  const AiTranslateSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AiTranslateSettingsViewModel(),
      child: Consumer<AiTranslateSettingsViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.settings),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: <Widget>[
                      DropdownButtonFormField<bool>(
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.outputType,
                          border: const OutlineInputBorder(),
                        ),
                        value: viewModel.isRichOutput,
                        items: [
                          DropdownMenuItem(
                            value: true,
                            child:
                                Text(AppLocalizations.of(context)!.richOutput),
                          ),
                          DropdownMenuItem(
                            value: false,
                            child: Text(
                                AppLocalizations.of(context)!.simpleOutput),
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
                          labelText:
                              AppLocalizations.of(context)!.translationProvider,
                          border: const OutlineInputBorder(),
                        ),
                        value: viewModel.translationProvider,
                        items: [
                          const DropdownMenuItem(
                            value: "ai",
                            child: Text("AI"),
                          ),
                          const DropdownMenuItem(
                            value: "google",
                            child: Text("Google"),
                          ),
                          const DropdownMenuItem(
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
                            border: OutlineInputBorder(),
                          ),
                          onChanged: viewModel.setDeeplxUrl,
                        ),
                      ],
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(AppLocalizations.of(context)!
                            .enableTranslationHistory),
                        value: viewModel.enableTranslationHistory,
                        onChanged: viewModel.setEnableTranslationHistory,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

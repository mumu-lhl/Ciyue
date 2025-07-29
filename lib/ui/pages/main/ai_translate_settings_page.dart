import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/ai_translate_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class AiTranslateSettingsPage extends StatelessWidget {
  const AiTranslateSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AiTranslateViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: Padding(
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
                  child: Text(AppLocalizations.of(context)!.richOutput),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text(AppLocalizations.of(context)!.simpleOutput),
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
                labelText: AppLocalizations.of(context)!.translationProvider,
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
              ],
              onChanged: (String? newValue) {
                if (newValue != null) {
                  viewModel.setTranslationProvider(newValue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

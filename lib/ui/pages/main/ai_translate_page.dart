import "package:ciyue/services/translation.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/main/ai_translate_settings_page.dart";
import "package:ciyue/viewModels/ai_translate_view_model.dart";
import "package:flutter/material.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:provider/provider.dart";

class AiTranslatePage extends StatelessWidget {
  const AiTranslatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AiTranslateViewModel(),
      child: Consumer<AiTranslateViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
              appBar: AppBar(
                actions: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: AppLocalizations.of(context)!.settings,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AiTranslateSettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _InputSection(
                            inputController: viewModel.inputController,
                          ),
                          _LanguageSelectionSection(
                            sourceLanguage: viewModel.sourceLanguage,
                            targetLanguage: viewModel.targetLanguage,
                            languageMap: languageMap,
                            getLanguageName: viewModel.getLanguageName,
                            onSourceChanged: (String? newValue) {
                              if (newValue != null) {
                                viewModel.setSourceLanguage(newValue);
                              }
                            },
                            onTargetChanged: (String? newValue) {
                              if (newValue != null) {
                                viewModel.setTargetLanguage(newValue);
                              }
                            },
                          ),
                          _TranslateButton(
                            onPressed: viewModel.inputController.text.isEmpty
                                ? null
                                : () => viewModel.translateText(context),
                          ),
                          if (viewModel.isLoading)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16.0),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          _TranslatedTextSection(
                              translatedText: viewModel.translatedText),
                        ],
                      ),
                    ),
                  ),
                ),
              ));
        },
      ),
    );
  }
}

class _InputSection extends StatelessWidget {
  const _InputSection({
    required this.inputController,
  });

  final TextEditingController inputController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: inputController,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.enterTextToTranslate,
          border: const OutlineInputBorder(),
        ),
        maxLines: null, // Allow multiple lines
      ),
    );
  }
}

class _LanguageSelectionSection extends StatelessWidget {
  const _LanguageSelectionSection({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.languageMap,
    required this.getLanguageName,
    required this.onSourceChanged,
    required this.onTargetChanged,
  });

  final String sourceLanguage;
  final String targetLanguage;
  final Map<String, String> languageMap;
  final String Function(String) getLanguageName;
  final ValueChanged<String?> onSourceChanged;
  final ValueChanged<String?> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.sourceLanguage,
              border: const OutlineInputBorder(),
            ),
            value: sourceLanguage,
            items:
                languageMap.keys.map<DropdownMenuItem<String>>((String code) {
              return DropdownMenuItem<String>(
                value: code,
                child: Text(getLanguageName(code) == "Auto Detect"
                    ? AppLocalizations.of(context)!.autoDetect
                    : getLanguageName(code)),
              );
            }).toList(),
            onChanged: onSourceChanged,
          ),
        ),
        const SizedBox(width: 16.0),
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.targetLanguage,
              border: const OutlineInputBorder(),
            ),
            value: targetLanguage,
            items: languageMap.keys
                .where((code) => code != "auto")
                .map<DropdownMenuItem<String>>((String code) {
              return DropdownMenuItem<String>(
                value: code,
                child: Text(getLanguageName(code)),
              );
            }).toList(),
            onChanged: onTargetChanged,
          ),
        ),
      ],
    );
  }
}

class _TranslateButton extends StatelessWidget {
  const _TranslateButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(AppLocalizations.of(context)!.translate),
      ),
    );
  }
}

class _TranslatedTextSection extends StatelessWidget {
  const _TranslatedTextSection({required this.translatedText});

  final String translatedText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: SelectionArea(
        child: GptMarkdown(
          translatedText,
        ),
      ),
    );
  }
}

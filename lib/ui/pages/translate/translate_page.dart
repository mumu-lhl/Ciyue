import "package:ciyue/database/app/app.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/language_picker.dart";
import "package:ciyue/ui/pages/translate/translate_history_page.dart";
import "package:ciyue/ui/pages/translate/translate_settings_page.dart";
import "package:ciyue/viewModels/translate_view_model.dart";
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
                  icon: const Icon(Icons.history),
                  tooltip: AppLocalizations.of(context)!.translationHistory,
                  onPressed: () async {
                    final result = await Navigator.push<TranslateHistoryData>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TranslateHistoryPage(),
                      ),
                    );
                    if (result != null) {
                      viewModel.inputController.text = result.inputText;
                    }
                  },
                ),
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
                        _LanguageSelectionRow(
                          sourceLanguage: viewModel.sourceLanguage,
                          targetLanguage: viewModel.targetLanguage,
                          getLanguageName: viewModel.getLanguageName,
                          onSwap: viewModel.swapLanguages,
                          onSourceTap: () => _showLanguagePicker(
                            context,
                            viewModel,
                            true,
                          ),
                          onTargetTap: () => _showLanguagePicker(
                            context,
                            viewModel,
                            false,
                          ),
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
                          translatedText: viewModel.translatedText,
                          translationProvider: viewModel.translationProvider,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    AiTranslateViewModel viewModel,
    bool isSource,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        widthFactor: 0.9,
        child: LanguagePicker(
          selectedLanguage:
              isSource ? viewModel.sourceLanguage : viewModel.targetLanguage,
          onLanguageSelected: (languageCode) {
            if (isSource) {
              viewModel.setSourceLanguage(languageCode);
            } else {
              viewModel.setTargetLanguage(languageCode);
            }
            Navigator.pop(context);
          },
          isSource: isSource,
        ),
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

class _LanguageSelectionRow extends StatelessWidget {
  const _LanguageSelectionRow({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.getLanguageName,
    required this.onSwap,
    required this.onSourceTap,
    required this.onTargetTap,
  });

  final String sourceLanguage;
  final String targetLanguage;
  final String Function(String) getLanguageName;
  final VoidCallback onSwap;
  final VoidCallback onSourceTap;
  final VoidCallback onTargetTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _LanguageChip(
            languageName: getLanguageName(sourceLanguage) == "Auto Detect"
                ? AppLocalizations.of(context)!.autoDetect
                : getLanguageName(sourceLanguage),
            onTap: onSourceTap,
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: onSwap,
          ),
          _LanguageChip(
            languageName: getLanguageName(targetLanguage),
            onTap: onTargetTap,
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.languageName, required this.onTap});

  final String languageName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(languageName),
      ),
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
  const _TranslatedTextSection({
    required this.translatedText,
    required this.translationProvider,
  });

  final String translatedText;
  final String translationProvider;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    switch (translationProvider) {
      case "AI":
        child = GptMarkdown(
          translatedText,
        );
        break;
      default:
        child = Text(
          translatedText,
          style: const TextStyle(fontSize: 20.0),
        );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: SelectionArea(
        child: child,
      ),
    );
  }
}

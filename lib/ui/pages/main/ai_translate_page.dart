import "dart:ui" as ui;

import "package:ciyue/services/ai.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";
import "package:gpt_markdown/gpt_markdown.dart";

class AiTranslatePage extends StatefulWidget {
  const AiTranslatePage({super.key});

  @override
  State<AiTranslatePage> createState() => _AiTranslatePageState();
}

class _AiTranslatePageState extends State<AiTranslatePage> {
  static const Map<String, String> _languageMap = {
    "auto": "Auto Detect",
    "en": "English",
    "zh": "简体中文",
    "zh_HK": "繁體中文",
    "zh_TW": "正體中文",
    "ja": "Japanese",
    "ko": "Korean",
    "fr": "French",
    "de": "Deutsch",
    "es": "Español",
    "ru": "Русский",
    "hi": "Hindi",
    "bn": "Bengali",
    "ca": "Catalan",
    "nb": "Bokmål",
    "sc": "Sardinian",
    "ta": "Tamil",
    "fa": "فارسی",
    "bg": "Bulgarian",
  };
  final TextEditingController _inputController = TextEditingController();
  bool _isRichOutput = true;
  String _sourceLanguage = "auto";
  String _targetLanguage = settings.language! == "system"
      ? ui.PlatformDispatcher.instance.locale.languageCode
      : settings.language!;

  String _translatedText = "";

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: AppLocalizations.of(context)!.more,
            onPressed: _showMoreDialog,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildInput(),
                buildLanguageSelection(),
                buildTranslateButton(),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                buildTranslatedText(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Padding buildInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: _inputController,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.enterTextToTranslate,
          border: const OutlineInputBorder(),
        ),
        maxLines: null, // Allow multiple lines
        onChanged: (String value) {
          setState(() {});
        },
      ),
    );
  }

  Row buildLanguageSelection() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.sourceLanguage,
              border: const OutlineInputBorder(),
            ),
            value: _sourceLanguage,
            items:
                _languageMap.keys.map<DropdownMenuItem<String>>((String code) {
              return DropdownMenuItem<String>(
                value: code,
                child: Text(_getLanguageName(code) == "Auto Detect"
                    ? AppLocalizations.of(context)!.autoDetect
                    : _getLanguageName(code)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _sourceLanguage = newValue!;
              });
            },
          ),
        ),
        const SizedBox(width: 16.0),
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.targetLanguage,
              border: const OutlineInputBorder(),
            ),
            value: _targetLanguage,
            items: _languageMap.keys
                .where((code) => code != "auto")
                .map<DropdownMenuItem<String>>((String code) {
              return DropdownMenuItem<String>(
                value: code,
                child: Text(_getLanguageName(code)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _targetLanguage = newValue!;
              });
            },
          ),
        ),
      ],
    );
  }

  Padding buildTranslateButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: ElevatedButton(
        onPressed: _inputController.text.isEmpty ? null : _translateText,
        child: Text(AppLocalizations.of(context)!.translate),
      ),
    );
  }

  Expanded buildTranslatedText() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: SingleChildScrollView(
          child: SelectionArea(
            child: GptMarkdown(
              _translatedText,
            ),
          ),
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    return _languageMap[code] ?? code;
  }

  void _showMoreDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.more),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<bool>(
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.outputType,
                  border: const OutlineInputBorder(),
                ),
                value: _isRichOutput,
                items: [
                  DropdownMenuItem(
                      value: true,
                      child: Text(AppLocalizations.of(context)!.richOutput)),
                  DropdownMenuItem(
                      value: false,
                      child: Text(AppLocalizations.of(context)!.simpleOutput)),
                ],
                onChanged: (bool? newValue) {
                  setState(() {
                    _isRichOutput = newValue!;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _translateText() async {
    setState(() {
      _isLoading = true;
      _translatedText = "";
    });

    try {
      final ai = AI(
        provider: settings.aiProvider,
        model: settings.getAiProviderConfig(settings.aiProvider)["model"] ?? "",
        apikey:
            settings.getAiProviderConfig(settings.aiProvider)["apiKey"] ?? "",
      );

      final sourceLangName = _languageMap[_sourceLanguage] ?? _sourceLanguage;
      final targetLangName = _languageMap[_targetLanguage] ?? _targetLanguage;
      final inputText = _inputController.text.trim();

      String template;
      if (settings.translatePromptMode == "custom" &&
          settings.customTranslatePrompt.isNotEmpty) {
        template = settings.customTranslatePrompt;
      } else if (_isRichOutput) {
        template = """
Translate the following text from \$sourceLanguage to \$targetLanguage. Please provide multiple translation options if possible. You must output the translation entirely and exclusively in \$targetLanguage: \$text
""";
      } else {
        template =
            'Translate this \$sourceLanguage sentence to \$targetLanguage, only return the translated text: "\$text"';
      }

      final prompt = template
          .replaceAll(r"$sourceLanguage", sourceLangName)
          .replaceAll(r"$targetLanguage", targetLangName)
          .replaceAll(r"$text", inputText);

      final translationResult = await ai.request(prompt);

      setState(() {
        _translatedText = translationResult;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _translatedText = "Error: Failed to translate. $e";
        _isLoading = false;
      });
    }
  }
}

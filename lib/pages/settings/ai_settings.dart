import 'package:ciyue/main.dart';
import 'package:ciyue/pages/main/home.dart';
import 'package:ciyue/settings.dart';
import 'package:ciyue/src/generated/i18n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AiSettings extends StatefulWidget {
  const AiSettings({super.key});

  @override
  State<AiSettings> createState() => _AiSettingsState();
}

class ModelInfo {
  final String originName;
  final String shownName;

  const ModelInfo(this.originName, this.shownName);
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

class _AiSettingsState extends State<AiSettings> {
  static const _providers = {
    "openai": "OpenAI",
    "gemini": "Gemini",
    "deepseek": "DeepSeek",
    "anthropic": "Anthropic",
  };
  static const _models = {
    "openai": [
      ModelInfo("gpt-4o-mini", "GPT-4o mini"),
      ModelInfo("gpt-4o", "GPT-4o"),
      ModelInfo("gpt-4.5-preview", "GPT-4.5 Preview"),
      ModelInfo("o1", "o1"),
      ModelInfo("o1-mini", "o1-mini"),
      ModelInfo("o3-mini", "o3-mini"),
    ],
    "gemini": [
      ModelInfo("gemini-2.5-pro-exp-03-25", "Gemini 2.5 Pro"),
      ModelInfo("gemini-2.0-flash", "Gemini 2.0 Flash"),
      ModelInfo("gemini-2.0-flash-lite", "Gemini 2.0 Flash Lite"),
      ModelInfo(
          "gemini-2.0-flash-thinking-exp-01-21", "Gemini 2.0 Flash Thinking"),
      ModelInfo("gemini-2.0-pro-exp-02-05", "Gemini 2.0 Pro"),
      ModelInfo("gemini-1.5-pro", "Gemini 1.5 Pro"),
      ModelInfo("gemini-1.5-flash", "Gemini 1.5 Flash"),
      ModelInfo("gemini-1.5-flash-8b", "Gemini 1.5 Flash-8B"),
    ],
    "deepseek": [
      ModelInfo("deepseek-chat", "DeepSeek Chat"),
      ModelInfo("deepseek-reasoner", "DeepSeek Reasoner"),
    ],
    "anthropic": [
      ModelInfo("claude-3-7-sonnet-latest", "Claude 3.7 Sonnet"),
      ModelInfo("claude-3-5-sonnet-latest", "Claude 3.5 Sonnet"),
      ModelInfo("claude-3-sonnet-20240229", "Claude 3 Sonnet"),
      ModelInfo("claude-3-5-haiku-latest", "Claude 3.5 Haiku"),
      ModelInfo("claude-3-haiku-20240307", "Claude 3 Haiku"),
      ModelInfo("claude-3-opus-latest", "Claude 3 Opus"),
    ]
  };
  String _provider = "";

  String _model = "";
  String _apiKey = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      AppLocalizations.of(context)!.aiSettings,
                    ),
                    const SizedBox(height: 12),
                    buildProvider(context),
                    const SizedBox(height: 24),

                    // AI Model
                    TitleText(
                      AppLocalizations.of(context)!.aiModel,
                    ),
                    const SizedBox(height: 12),
                    buildModel(context),
                    const SizedBox(height: 24),

                    // API Key
                    TitleText(
                      AppLocalizations.of(context)!.apiKey,
                    ),
                    const SizedBox(height: 12),
                    buildAPIKey(context),
                    const SizedBox(height: 24),

                    // Explain Word
                    buildExplainWord(context),
                    const SizedBox(height: 24),

                    // Explain Word Prompt Setting
                    TitleText(AppLocalizations.of(context)!.aiExplainWordPrompt),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: settings.explainPromptMode,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: AppLocalizations.of(context)!.promptMode,
                      ),
                      items: [
                        DropdownMenuItem(
                            value: "default",
                            child: Text(AppLocalizations.of(context)!.default_)),
                        DropdownMenuItem(
                            value: "custom",
                            child: Text(AppLocalizations.of(context)!.customOption)),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        await settings.setExplainPromptMode(value);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    if (settings.explainPromptMode == "custom")
                      TextFormField(
                        initialValue: settings.customExplainPrompt,
                        maxLines: null,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.customExplainPrompt,
                          helperText: AppLocalizations.of(context)!.customExplainPromptHelper,
                        ),
                        onChanged: (value) async {
                          await settings.setCustomExplainPrompt(value);
                        },
                      ),
                    const SizedBox(height: 24),

                    // AI Translate Prompt Setting
                    TitleText(AppLocalizations.of(context)!.aiTranslatePrompt),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: settings.translatePromptMode,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: AppLocalizations.of(context)!.promptMode,
                      ),
                      items: [
                        DropdownMenuItem(
                            value: "default",
                            child: Text(AppLocalizations.of(context)!.default_)),
                        DropdownMenuItem(
                            value: "custom",
                            child: Text(AppLocalizations.of(context)!.customOption)),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        await settings.setTranslatePromptMode(value);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    if (settings.translatePromptMode == "custom")
                      TextFormField(
                        initialValue: settings.customTranslatePrompt,
                        maxLines: null,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.customTranslatePrompt,
                          helperText: AppLocalizations.of(context)!.customTranslatePromptHelper,
                        ),
                        onChanged: (value) async {
                          await settings.setCustomTranslatePrompt(value);
                        },
                      ),
                  ],
                ),
              ),
            )),
      ),
    );
  }

  TextFormField buildAPIKey(BuildContext context) {
    return TextFormField(
      key: ValueKey(_apiKey),
      initialValue: _apiKey,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        hintText: AppLocalizations.of(context)!.apiKey,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: (value) {
        _apiKey = value;
        _saveAiProviderConfig();
      },
      obscureText: true,
    );
  }

  Widget buildExplainWord(BuildContext context) {
    return Row(
      children: [
        TitleText(
          AppLocalizations.of(context)!.aiExplainWord,
        ),
        const Spacer(),
        Switch(
          value: settings.aiExplainWord,
          onChanged: (value) {
            setState(() {
              settings.aiExplainWord = value;
              prefs.setBool('aiExplainWord', value);
              context.read<HomeModel>().update();
            });
          },
        ),
      ],
    );
  }

  DropdownButtonFormField<String> buildModel(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _models[_provider]!.any((m) => m.originName == _model)
          ? _model
          : _models[_provider]![0].originName,
      hint: Text(AppLocalizations.of(context)!.aiModel),
      padding: EdgeInsets.only(left: 8, right: 8),
      onChanged: (String? newValue) {
        setState(() {
          _model = newValue ?? "";
          _saveAiProviderConfig();
        });
      },
      items:
          _models[_provider]!.map<DropdownMenuItem<String>>((ModelInfo value) {
        return DropdownMenuItem<String>(
          value: value.originName,
          child: Text(value.shownName),
        );
      }).toList(),
    );
  }

  DropdownButtonFormField<String> buildProvider(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _provider,
      hint: Text(AppLocalizations.of(context)!.aiProvider),
      padding: EdgeInsets.only(left: 8, right: 8),
      onChanged: (String? newValue) {
        setState(() {
          _provider = newValue!;
          settings.aiProvider = newValue;
          prefs.setString('aiProvider', newValue);

          final config = settings.getAiProviderConfig(_provider);
          _model = config['model']!;
          _apiKey = config['apiKey']!;
        });
      },
      items: _providers.keys
          .toList()
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(_providers[value]!),
        );
      }).toList(),
    );
  }

  @override
  void initState() {
    super.initState();

    _provider = settings.aiProvider;

    final config = settings.getAiProviderConfig(_provider);
    _model = config['model']!;
    _apiKey = config['apiKey']!;
  }

  void _saveAiProviderConfig() {
    settings.saveAiProviderConfig(_provider, _model, _apiKey);
  }
}

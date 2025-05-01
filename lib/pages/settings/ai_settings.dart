import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/main.dart";
import "package:ciyue/pages/main/home.dart";
import "package:ciyue/services/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class AiSettings extends StatefulWidget {
  const AiSettings({super.key});

  @override
  State<AiSettings> createState() => _AiSettingsState();
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
                    TitleText(
                        AppLocalizations.of(context)!.aiExplainWordPrompt),
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
                            child:
                                Text(AppLocalizations.of(context)!.default_)),
                        DropdownMenuItem(
                            value: "custom",
                            child: Text(
                                AppLocalizations.of(context)!.customOption)),
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
                          labelText:
                              AppLocalizations.of(context)!.customExplainPrompt,
                          helperText: AppLocalizations.of(context)!
                              .customExplainPromptHelper,
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
                            child:
                                Text(AppLocalizations.of(context)!.default_)),
                        DropdownMenuItem(
                            value: "custom",
                            child: Text(
                                AppLocalizations.of(context)!.customOption)),
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
                          labelText: AppLocalizations.of(context)!
                              .customTranslatePrompt,
                          helperText: AppLocalizations.of(context)!
                              .customTranslatePromptHelper,
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
              prefs.setBool("aiExplainWord", value);
              context.read<HomeModel>().update();
            });
          },
        ),
      ],
    );
  }

  Widget buildModel(BuildContext context) {
    final currentProvider = ModelProviderManager.modelProviders[_provider] ??
        ModelProviderManager.modelProviders.values.first;

    if (currentProvider.allowCustomModel) {
      return TextFormField(
        key: ValueKey(_provider + _model),
        initialValue: _model,
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          hintText: AppLocalizations.of(context)!.aiModel,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onChanged: (value) {
          _model = value;
          _saveAiProviderConfig();
        },
      );
    } else {
      final currentModels = currentProvider.models;
      return DropdownButtonFormField<String>(
        value: currentModels.any((m) => m.originName == _model)
            ? _model
            : currentModels[0].originName,
        hint: Text(AppLocalizations.of(context)!.aiModel),
        padding: EdgeInsets.only(left: 8, right: 8),
        onChanged: (String? newValue) {
          setState(() {
            _model = newValue ?? "";
            _saveAiProviderConfig();
          });
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

  DropdownButtonFormField<String> buildProvider(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _provider,
      hint: Text(AppLocalizations.of(context)!.aiProvider),
      padding: EdgeInsets.only(left: 8, right: 8),
      onChanged: (String? newValue) {
        setState(() {
          _provider = newValue!;
          settings.aiProvider = newValue;
          prefs.setString("aiProvider", newValue);

          final config = settings.getAiProviderConfig(_provider);
          _model = config["model"]!;
          // Ensure the selected model is valid for the new provider
          final currentProvider =
              ModelProviderManager.modelProviders[_provider] ??
                  ModelProviderManager.modelProviders.values.first;
          if (!currentProvider.models.any((m) => m.originName == _model) &&
              !currentProvider.allowCustomModel) {
            _model = currentProvider.models[0].originName;
          }
          _apiKey = config["apiKey"]!;
        });
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

  @override
  void initState() {
    super.initState();

    _provider = settings.aiProvider;
    // Ensure provider exists
    if (ModelProviderManager.modelProviders[_provider] == null) {
      _provider = ModelProviderManager.modelProviders.values.first.name;
      settings.aiProvider = _provider;
      prefs.setString("aiProvider", _provider);
    }

    final config = settings.getAiProviderConfig(_provider);
    _model = config["model"]!;
    _apiKey = config["apiKey"]!;

    // Ensure model exists for the provider
    final currentProvider = ModelProviderManager.modelProviders[_provider]!;
    if (!currentProvider.models.any((m) => m.originName == _model) &&
        !currentProvider.allowCustomModel) {
      _model = currentProvider.models[0].originName;
      _saveAiProviderConfig(); // Save the default model if the saved one was invalid
    }
  }

  void _saveAiProviderConfig() {
    settings.saveAiProviderConfig(_provider, _model, _apiKey);
  }
}

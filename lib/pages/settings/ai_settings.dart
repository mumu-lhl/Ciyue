import 'package:ciyue/main.dart';
import 'package:ciyue/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

class _AiSettingsState extends State<AiSettings> {
  String _provider = "";
  String _model = "";
  String _apiKey = "";

  static const _providers = {
    "openai": "OpenAI",
    "gemini": "Gemini",
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
      ModelInfo("gemini-2.0-flash", "Gemini 2.0 Flash"), 
      ModelInfo("gemini-2.0-flash-lite", "Gemini 2.0 Flash Thinking Lite"),
      ModelInfo("gemini-2.0-flash-thinking-exp-01-21", "Gemini 2.0 Flash Thinking"),
      ModelInfo("gemini-2.0-pro-exp-02-05", "Gemini 2.0 Pro"),
      ModelInfo("gemini-1.5-pro", "Gemini 1.5 Pro"),
      ModelInfo("gemini-1.5-flash", "Gemini 1.5 Flash"),
      ModelInfo("gemini-1.5-flash-8b", "Gemini 1.5 Flash-8B"),
    ]
  };

  @override
  void initState() {
    super.initState();

    _provider = settings.aiProvider;

    final config = settings.getAiProviderConfig(_provider);
    _model = config['model']!;
    _apiKey = config['apiKey']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.aiSettings),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.aiProvider,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
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
              items: _providers.keys.toList()
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(_providers[value]!),
                );
              }).toList(),
            ),
            SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.aiModel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
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
              items: _models[_provider]!
                  .map<DropdownMenuItem<String>>((ModelInfo value) {
                return DropdownMenuItem<String>(
                  value: value.originName,
                  child: Text(value.shownName),
                );
              }).toList(),
            ),
            SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.apiKey,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            TextFormField(
              key: ValueKey(_apiKey),
              initialValue: _apiKey,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: AppLocalizations.of(context)!.apiKey,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (value) {
                _apiKey = value;
                _saveAiProviderConfig();
              },
              obscureText: true,
            )
          ],
        ),
      ),
    );
  }

  void _saveAiProviderConfig() {
    settings.saveAiProviderConfig(_provider, _model, _apiKey);
  }
}

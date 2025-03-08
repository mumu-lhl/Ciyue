import 'package:ciyue/main.dart';
import 'package:ciyue/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AiSettings extends StatefulWidget {
  const AiSettings({super.key});

  @override
  State<AiSettings> createState() => _AiSettingsState();
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
    "openai": ["gpt-3.5-turbo", "gpt-4"],
    "gemini": ["gemini-pro"]
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
              value: _model == "" ? _models[_provider]![0] : _model,
              hint: Text(AppLocalizations.of(context)!.aiModel),
              padding: EdgeInsets.only(left: 8, right: 8),
              onChanged: (String? newValue) {
                setState(() {
                  _model = newValue ?? "";
                  _saveAiProviderConfig();
                });
              },
              items: _models[_provider]!
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
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

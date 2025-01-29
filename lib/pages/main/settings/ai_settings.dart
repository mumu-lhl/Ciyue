import 'dart:convert';

import "package:ciyue/main.dart";
import "package:ciyue/settings.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";

class AISettingsPage extends StatefulWidget {
  const AISettingsPage({super.key});

  @override
  State<AISettingsPage> createState() => _AISettingsPageState();
}

class _AISettingsPageState extends State<AISettingsPage> {
  String _selectedProvider = settings.aiProvider;
  late TextEditingController _apiKeyController;

  Column aiModel() {
    return Column(
      children: [
        Text(AppLocalizations.of(context)!.aiModel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        DropdownButtonFormField<String>(
          value: settings.currentAIProviderConfig.model,
          items: const [
            DropdownMenuItem(value: "gpt-4o-mini", child: Text("gpt-4o-mini")),
            DropdownMenuItem(value: "gemini-2", child: Text("gemini-2")),
            DropdownMenuItem(value: "deepseek-r1", child: Text("deepseek-r1")),
          ],
          onChanged: (value) async {
            final updatedConfig = settings.aiProviderConfigs.firstWhere(
                (config) => config.provider == _selectedProvider,
                orElse: () => AIProviderConfig(
                    provider: _selectedProvider, apiKey: "", model: ""));
            final index = settings.aiProviderConfigs.indexOf(updatedConfig);
            if (index != -1) {
              settings.aiProviderConfigs[index] = AIProviderConfig(
                  provider: _selectedProvider,
                  apiKey: _apiKeyController.text,
                  model: value!);
            } else {
              settings.aiProviderConfigs.add(AIProviderConfig(
                  provider: _selectedProvider,
                  apiKey: _apiKeyController.text,
                  model: value!));
            }
            await prefs.setStringList(
                "aiProviderConfigs",
                settings.aiProviderConfigs
                    .map((e) => jsonEncode(e.toJson()))
                    .toList());
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Column aiProvider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.aiProvider,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedProvider,
          items: const [
            DropdownMenuItem(value: "OpenAI", child: Text("OpenAI")),
            DropdownMenuItem(value: "Gemini", child: Text("Gemini")),
            DropdownMenuItem(value: "Deepseek", child: Text("Deepseek")),
          ],
          onChanged: (value) async {
            await prefs.setString("aiProvider", value!);
            setState(() {
              settings.aiProvider = value;
              _selectedProvider = value;
              _apiKeyController.text = settings.currentAIProviderConfig.apiKey;
            });
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Column apiKey() {
    return Column(
      children: [
        Text(AppLocalizations.of(context)!.apiKey,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        TextFormField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.enterApiKey,
          ),
          onChanged: (value) async {
            final updatedConfig = settings.aiProviderConfigs.firstWhere(
                (config) => config.provider == _selectedProvider,
                orElse: () => AIProviderConfig(
                    provider: _selectedProvider, apiKey: "", model: ""));
            final index = settings.aiProviderConfigs.indexOf(updatedConfig);
            if (index != -1) {
              settings.aiProviderConfigs[index] = AIProviderConfig(
                  provider: _selectedProvider,
                  apiKey: value,
                  model: settings.currentAIProviderConfig.model);
            } else {
              settings.aiProviderConfigs.add(AIProviderConfig(
                  provider: _selectedProvider,
                  apiKey: value,
                  model: settings.currentAIProviderConfig.model));
            }
            await prefs.setStringList(
                "aiProviderConfigs",
                settings.aiProviderConfigs
                    .map((e) => jsonEncode(e.toJson()))
                    .toList());
            setState(() {});
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.aiSettings),
        ),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                aiProvider(),
                aiModel(),
                apiKey(),
              ],
            ),
          ),
        )));
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _apiKeyController =
        TextEditingController(text: settings.currentAIProviderConfig.apiKey);
  }
}

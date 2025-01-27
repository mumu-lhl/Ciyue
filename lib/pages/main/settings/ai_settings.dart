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
                Text(AppLocalizations.of(context)!.aiProvider,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: _selectedProvider,
                  items: const [
                    DropdownMenuItem(value: 'OpenAI', child: Text('OpenAI')),
                    DropdownMenuItem(value: 'Gemini', child: Text('Gemini')),
                    DropdownMenuItem(
                        value: 'Deepseek', child: Text('Deepseek')),
                  ],
                  onChanged: (value) async {
                    await prefs.setString("aiProvider", value!);
                    setState(() {
                      settings.aiProvider = value;
                      _selectedProvider = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.apiKey,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextFormField(
                  initialValue: settings.apiKey,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.enterApiKey,
                  ),
                  onChanged: (value) async {
                    await prefs.setString("apiKey", value);
                    setState(() {
                      settings.apiKey = value;
                    });
                  },
                ),
              ],
            ),
          ),
        )));
  }
}

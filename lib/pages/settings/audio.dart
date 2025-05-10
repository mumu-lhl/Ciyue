import "dart:io";

import "package:ciyue/main.dart";
import "package:ciyue/pages/settings/ai_settings.dart";
import "package:ciyue/services/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";

class AudioSettings extends StatelessWidget {
  const AudioSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (Platform.isAndroid) TTSEngines(),
                  TTSLanguages(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TTSEngines extends StatelessWidget {
  const TTSEngines({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleText(AppLocalizations.of(context)!.ttsEngines),
        SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: settings.ttsEngine ?? ttsEngines.first,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.ttsEngines,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final engine in ttsEngines)
              DropdownMenuItem(
                value: engine,
                child: Text((engine as String)
                    .replaceFirst(RegExp(r"^com\."), "")
                    .split(".")
                    .map((e) => e.isEmpty
                        ? ""
                        : "${e[0].toUpperCase()}${e.substring(1)}")
                    .join(" ")),
              )
          ],
          onChanged: (String? ttsEngine) async {
            if (ttsEngine != null) {
              settings.setTTSEngine(ttsEngine);
              flutterTts.setEngine(ttsEngine);
            }
          },
        ),
        SizedBox(height: 24),
      ],
    );
  }
}

class TTSLanguages extends StatelessWidget {
  const TTSLanguages({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleText(AppLocalizations.of(context)!.ttsLanguages),
        SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: settings.ttsLanguage ?? _defaultLanguage(),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.ttsLanguages,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final lang in ttsLanguages)
              DropdownMenuItem(
                value: lang,
                child: Text(lang),
              )
          ],
          onChanged: (String? ttsLanguage) async {
            if (ttsLanguage != null) {
              settings.setTTSLanguage(ttsLanguage);
              flutterTts.setLanguage(ttsLanguage);
            }
          },
        )
      ],
    );
  }

  String _defaultLanguage() {
    if (ttsLanguages.contains("en-US")) {
      return "en-US";
    }

    if (ttsLanguages.isNotEmpty) {
      return ttsLanguages.first;
    }

    return "";
  }
}

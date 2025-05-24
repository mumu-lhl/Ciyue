import "dart:io";

import "package:ciyue/main.dart";
import "package:ciyue/pages/settings/ai_settings.dart";
import "package:ciyue/services/dictionary.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class AudioItems extends StatelessWidget {
  const AudioItems({super.key});

  @override
  Widget build(BuildContext context) {
    context.select<AudioModel, int>((model) => model.mddAudioListState);
    final mddAudioList = context.read<AudioModel>().mddAudioList;

    return Expanded(
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: mddAudioList.length + 1,
        itemBuilder: (context, index) {
          if (index == mddAudioList.length) {
            return Card(
              key: ValueKey("tts_option"),
              color: Theme.of(context).colorScheme.onInverseSurface,
              child: ListTile(
                title: const Text("TTS"),
              ),
            );
          } else {
            final mddAudio = mddAudioList[index];
            return Card(
              color: Theme.of(context).colorScheme.onInverseSurface,
              key: ValueKey(mddAudio.id),
              child: ListTile(
                leading: ReorderableDragStartListener(
                  index: index,
                  child: IconButton(icon: Icon(Icons.menu), onPressed: () {}),
                ),
                title: Text(mddAudio.title),
                trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () async {
                      await context
                          .read<AudioModel>()
                          .removeMddAudio(mddAudio.id);
                    }),
              ),
            );
          }
        },
        onReorder: (oldIndex, newIndex) {
          if (oldIndex >= mddAudioList.length ||
              newIndex >= mddAudioList.length) {
            return;
          }
          context.read<AudioModel>().reorderMddAudio(oldIndex, newIndex);
        },
      ),
    );
  }
}

class AudioList extends StatelessWidget {
  const AudioList({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () async {
                if (Platform.isAndroid) {
                  PlatformMethod.openAudioDirectory();
                } else {
                  await selectMdxOrMdd(context, false);
                }
              },
            ),
          ],
        ),
        AudioItems(),
      ],
    );
  }
}

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
                  SizedBox(height: 24),
                  if (Platform.isAndroid) TTSEngines(),
                  if (!Platform.isLinux) TTSLanguages(),
                  Expanded(child: AudioList()),
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

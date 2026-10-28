import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/audio.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/services/tts.dart";
import "package:ciyue/ui/core/title_text.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/core/providers.dart";
import "package:file_selector/file_selector.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class AudioSettingsPage extends ConsumerWidget {
  const AudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when settings change so the texts that depend on the
    // pronunciation mode (pack description, TTS card note) stay current.
    ref.watch(settingsProvider);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.audioSettings),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                // See the Hunspell page: keep the last row clear of the navigation bar.
                bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                const SizedBox(height: 8),
                const PronunciationModeSelector(),
                const SizedBox(height: 24),
                const AudioList(),
                const SizedBox(height: 24),
                if (Platform.isAndroid) const TTSEngines(),
                if (!Platform.isLinux) ...[
                  const TTSLanguages(),
                  const TTSSpeechControls(),
                ] else
                  Text(
                    AppLocalizations.of(context)!.ttsUnsupportedOnPlatform,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PronunciationModeSelector extends StatelessWidget {
  const PronunciationModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleText(localizations.pronunciation),
        const SizedBox(height: 12),
        DropdownButtonFormField<PronunciationMode>(
          initialValue: settings.pronunciationMode,
          decoration: InputDecoration(
            labelText: localizations.pronunciation,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            DropdownMenuItem(
              value: PronunciationMode.packFirst,
              child: Text(localizations.pronunciationPackFirst),
            ),
            DropdownMenuItem(
              value: PronunciationMode.packOnly,
              child: Text(localizations.pronunciationPackOnly),
            ),
            DropdownMenuItem(
              value: PronunciationMode.ttsOnly,
              child: Text(localizations.pronunciationTtsOnly),
            ),
          ],
          onChanged: (mode) {
            if (mode != null) {
              settings.setPronunciationMode(mode);
            }
          },
        ),
      ],
    );
  }
}

class AudioList extends ConsumerWidget {
  const AudioList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    ref.watch(audioModelProvider.select((model) => model.mddAudioListState));
    final mddAudioList = ref.read(audioModelProvider).mddAudioList;
    final packsOff = settings.pronunciationMode == PronunciationMode.ttsOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleText(localizations.pronunciationPacks),
        const SizedBox(height: 8),
        Text(
          packsOff
              ? localizations.pronunciationPacksDescriptionPacksOff
              : localizations.pronunciationPacksDescription,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add),
              label: Text(localizations.addPronunciationPack),
              onPressed: () async {
                if (Platform.isAndroid) {
                  if (isFullFlavor()) {
                    final isGranted = await requestManageExternalStorage(
                      context,
                    );
                    if (isGranted) {
                      final path = await getDirectoryPath();
                      if (path != null) {
                        await prefs.setString("audioDirectory", path);

                        final paths = await findMddAudioFilesOnAndroid(path);
                        if (paths.isEmpty) {
                          if (context.mounted) {
                            await ToastService.show(
                              localizations.noMddAudioFound,
                              context,
                              type: ToastType.info,
                            );
                          }
                        } else if (context.mounted) {
                          await selectAudioMdd(context, paths);
                        }
                      }
                    }
                  } else {
                    PlatformMethod.openAudioDirectory();
                  }
                } else {
                  await selectMddOnDesktop(context);
                }
              },
            ),
          ],
        ),
        if (mddAudioList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              localizations.noPronunciationPacks,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const AudioItems(),
      ],
    );
  }
}

class AudioItems extends ConsumerWidget {
  const AudioItems({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(audioModelProvider.select((model) => model.mddAudioListState));
    final audioModel = ref.read(audioModelProvider);
    final mddAudioList = audioModel.mddAudioList;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: mddAudioList.length + 1,
      itemBuilder: (context, index) {
        final theme = Theme.of(context);
        if (index == mddAudioList.length) {
          return Card(
            key: const ValueKey("tts_option"),
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: ListTile(
              title: const Text("TTS"),
              subtitle: Text(_ttsCardNote(context)),
            ),
          );
        }
        final mddAudio = mddAudioList[index];
        final count = audioModel.mddAudioCounts[mddAudio.id];
        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          key: ValueKey(mddAudio.id),
          child: ListTile(
            leading: ReorderableDragStartListener(
              index: index,
              child: IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
            ),
            title: Text(mddAudio.title),
            subtitle: count == null
                ? null
                : Text(
                    AppLocalizations.of(context)!
                        .pronunciationPackEntryCount(count),
                  ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: theme.colorScheme.error),
              onPressed: () =>
                  _confirmRemove(context, ref, mddAudio.id, mddAudio.title),
            ),
          ),
        );
      },
      onReorderItem: (oldIndex, newIndex) {
        if (oldIndex >= mddAudioList.length ||
            newIndex >= mddAudioList.length) {
          return;
        }
        ref.read(audioModelProvider).reorderMddAudio(oldIndex, newIndex);
      },
    );
  }

  String _ttsCardNote(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (Platform.isLinux) {
      return localizations.ttsUnsupportedOnPlatform;
    }
    return switch (settings.pronunciationMode) {
      PronunciationMode.packFirst => localizations.ttsFallbackNote,
      PronunciationMode.packOnly => localizations.ttsPacksOffNote,
      PronunciationMode.ttsOnly => localizations.ttsOnlyModeNote,
    };
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    int id,
    String title,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    // The file is deleted with the entry only when it is an app-owned
    // copy (Android common flavor imports); full-flavor packs point at
    // the user's own files, which are kept.
    final copyDeleted = Platform.isAndroid && !isFullFlavor();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.removePronunciationPackTitle(title)),
        content: Text(
          copyDeleted
              ? localizations.removePronunciationPackBodyCopyDeleted
              : localizations.removePronunciationPackBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.remove),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(audioModelProvider).removeMddAudio(id);
    }
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
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue:
              settings.ttsEngine ??
              (ttsEngines.isNotEmpty ? ttsEngines.first : null),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.ttsEngines,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            for (final engine in ttsEngines)
              DropdownMenuItem(
                value: engine,
                child: Text(
                  engine
                      .replaceFirst(RegExp(r"^com\."), "")
                      .split(".")
                      .map(
                        (e) => e.isEmpty
                            ? ""
                            : "${e[0].toUpperCase()}${e.substring(1)}",
                      )
                      .join(" "),
                ),
              ),
          ],
          onChanged: (String? ttsEngine) async {
            if (ttsEngine != null) {
              settings.setTTSEngine(ttsEngine);
              flutterTts.setEngine(ttsEngine);
            }
          },
        ),
        const SizedBox(height: 24),
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
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: settings.ttsLanguage ?? _defaultLanguage(),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.ttsLanguages,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            for (final lang in ttsLanguages)
              DropdownMenuItem(value: lang, child: Text(lang)),
          ],
          onChanged: (String? ttsLanguage) async {
            if (ttsLanguage != null) {
              settings.setTTSLanguage(ttsLanguage);
              flutterTts.setLanguage(ttsLanguage);
            }
          },
        ),
        const SizedBox(height: 24),
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

/// Speech rate / pitch sliders plus a preview button, so TTS changes can
/// be heard immediately instead of only when looking up a word.
class TTSSpeechControls extends StatefulWidget {
  const TTSSpeechControls({super.key});

  @override
  State<TTSSpeechControls> createState() => _TTSSpeechControlsState();
}

class _TTSSpeechControlsState extends State<TTSSpeechControls> {
  late double _rate = settings.ttsSpeechRate;
  late double _pitch = settings.ttsPitch;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sliderRow(
          label: localizations.ttsSpeechRate,
          value: _rate,
          min: 0.1,
          max: 1.0,
          divisions: 18,
          onChanged: (value) => setState(() => _rate = value),
          onChangeEnd: (value) async {
            await settings.setTTSSpeechRate(value);
            await flutterTts.setSpeechRate(value);
          },
        ),
        _sliderRow(
          label: localizations.ttsPitch,
          value: _pitch,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          onChanged: (value) => setState(() => _pitch = value),
          onChangeEnd: (value) async {
            await settings.setTTSPitch(value);
            await flutterTts.setPitch(value);
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text(localizations.ttsPreview),
            onPressed: () async {
              await applyTtsSettings(flutterTts);
              await flutterTts.speak(localizations.ttsPreviewText);
            },
          ),
        ),
      ],
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

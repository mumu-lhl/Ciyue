import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/audio.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/services/linux_tts.dart";
import "package:ciyue/services/linux_tts_driver.dart";
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
import "package:simple_secure_storage/simple_secure_storage.dart";
import "package:url_launcher/url_launcher.dart";

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
                const OnlinePronunciationSettings(),
                const SizedBox(height: 24),
                if (Platform.isAndroid) const TTSEngines(),
                if (!Platform.isLinux) ...[
                  const TTSLanguages(),
                  const TTSSpeechControls(),
                ] else ...[
                  const LinuxTtsSettings(),
                  const TTSSpeechControls(),
                ],
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
          isExpanded: true,
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

                        final paths = await findAudioPackFilesOnAndroid(path);
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
              child: IconButton(
                icon: const Icon(Icons.drag_handle_rounded),
                onPressed: () {},
              ),
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

class OnlinePronunciationSettings extends StatefulWidget {
  const OnlinePronunciationSettings({super.key});

  @override
  State<OnlinePronunciationSettings> createState() =>
      _OnlinePronunciationSettingsState();
}

class _OnlinePronunciationSettingsState
    extends State<OnlinePronunciationSettings> {
  static const _forvoApiKeyStorageKey = "forvoApiKey";
  static const _forvoApiKeyPlaceholder = "••••••••";
  static const _onlinePronunciationLanguages = <String, String>{
    "en": "English",
    "de": "German",
    "fr": "French",
    "es": "Spanish",
    "it": "Italian",
    "pt": "Portuguese",
    "ru": "Russian",
    "ja": "Japanese",
    "ko": "Korean",
    "zh": "Chinese",
    "nl": "Dutch",
    "sv": "Swedish",
    "da": "Danish",
    "no": "Norwegian",
    "fi": "Finnish",
    "pl": "Polish",
    "cs": "Czech",
    "hu": "Hungarian",
    "tr": "Turkish",
    "ar": "Arabic",
    "he": "Hebrew",
    "hi": "Hindi",
    "th": "Thai",
    "vi": "Vietnamese",
    "id": "Indonesian",
    "uk": "Ukrainian",
    "el": "Greek",
  };

  final _forvoApiKeyController = TextEditingController();
  final _forvoApiKeyFocusNode = FocusNode();

  bool _hasStoredForvoApiKey = false;
  bool _forvoApiKeyDirty = false;
  bool _placeholderClearedOnFocus = false;

  /// Guards programmatic controller writes (placeholder load/restore)
  /// from the field's onChanged handler: setting controller text
  /// programmatically fires onChanged, and without this guard merely
  /// focusing and leaving the field would mark it edited and delete
  /// the stored key on blur.
  bool _suppressForvoApiKeyChanged = false;

  @override
  void initState() {
    super.initState();
    _forvoApiKeyFocusNode.addListener(_onForvoApiKeyFocusChanged);
    _loadForvoApiKey();
  }

  @override
  void dispose() {
    _forvoApiKeyFocusNode.removeListener(_onForvoApiKeyFocusChanged);
    _forvoApiKeyFocusNode.dispose();
    _forvoApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadForvoApiKey() async {
    final storedKey = await SimpleSecureStorage.read(_forvoApiKeyStorageKey);
    if (!mounted) return;
    if (storedKey != null && storedKey.isNotEmpty) {
      _hasStoredForvoApiKey = true;
      // Show obscured placeholder dots, never the stored key itself.
      // Suppressed: this programmatic write must not mark the field edited.
      _suppressForvoApiKeyChanged = true;
      _forvoApiKeyController.text = _forvoApiKeyPlaceholder;
      _suppressForvoApiKeyChanged = false;
    }
    setState(() {});
  }

  void _onForvoApiKeyFocusChanged() {
    if (!_forvoApiKeyFocusNode.hasFocus) {
      if (_placeholderClearedOnFocus) {
        // Focused but nothing was typed: restore the placeholder
        // instead of treating the cleared field as a key deletion.
        _placeholderClearedOnFocus = false;
        _suppressForvoApiKeyChanged = true;
        _forvoApiKeyController.text = _forvoApiKeyPlaceholder;
        _suppressForvoApiKeyChanged = false;
        return;
      }
      _saveForvoApiKey();
      return;
    }
    if (_hasStoredForvoApiKey && !_forvoApiKeyDirty) {
      // Editing replaces the stored key, so start from an empty field
      // rather than letting the placeholder dots become part of the key.
      _placeholderClearedOnFocus = true;
      _suppressForvoApiKeyChanged = true;
      _forvoApiKeyController.clear();
      _suppressForvoApiKeyChanged = false;
    }
  }

  Future<void> _saveForvoApiKey() async {
    if (!_forvoApiKeyDirty) return;
    final value = _forvoApiKeyController.text.trim();
    if (value.isEmpty) {
      await SimpleSecureStorage.delete(_forvoApiKeyStorageKey);
    } else {
      await SimpleSecureStorage.write(_forvoApiKeyStorageKey, value);
    }
    if (!mounted) return;
    _hasStoredForvoApiKey = value.isNotEmpty;
    _forvoApiKeyDirty = false;
    _placeholderClearedOnFocus = false;
    if (value.isNotEmpty) {
      _suppressForvoApiKeyChanged = true;
      _forvoApiKeyController.text = _forvoApiKeyPlaceholder;
      _suppressForvoApiKeyChanged = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final helperStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final packsFirst =
        settings.pronunciationMode == PronunciationMode.packFirst;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleText(localizations.onlinePronunciation),
        const SizedBox(height: 8),
        Text(localizations.onlinePronunciationDescription, style: helperStyle),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(localizations.onlinePronunciationWiktionary),
          value: settings.wiktionaryPronunciationEnabled,
          onChanged: (value) {
            settings.setWiktionaryPronunciationEnabled(value);
          },
        ),
        _languageDropdown(
          localizations: localizations,
          enabled: settings.wiktionaryPronunciationEnabled,
          value: settings.wiktionaryPronunciationLanguage,
          onChanged: (language) {
            settings.setWiktionaryPronunciationLanguage(language);
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(localizations.onlinePronunciationForvo),
          value: settings.forvoPronunciationEnabled,
          onChanged: (value) {
            settings.setForvoPronunciationEnabled(value);
          },
        ),
        _languageDropdown(
          localizations: localizations,
          enabled: settings.forvoPronunciationEnabled,
          value: settings.forvoPronunciationLanguage,
          onChanged: (language) {
            settings.setForvoPronunciationLanguage(language);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _forvoApiKeyController,
          focusNode: _forvoApiKeyFocusNode,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: localizations.onlinePronunciationForvoApiKey,
            helperText: localizations.onlinePronunciationForvoApiKeyHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (_) {
            // Programmatic controller writes (placeholder load/restore)
            // must not mark the field edited: without this guard,
            // merely focusing and leaving the field would delete the
            // stored key.
            if (_suppressForvoApiKeyChanged) return;
            _placeholderClearedOnFocus = false;
            _forvoApiKeyDirty = true;
          },
          onSubmitted: (_) {
            _saveForvoApiKey();
            _forvoApiKeyFocusNode.unfocus();
          },
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => launchUrl(Uri.parse("https://forvo.com")),
          child: Text(
            localizations.onlinePronunciationForvoAttribution,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        if (!packsFirst) ...[
          const SizedBox(height: 8),
          Text(
            localizations.onlinePronunciationDisabledNote,
            style: helperStyle,
          ),
        ],
      ],
    );
  }

  Widget _languageDropdown({
    required AppLocalizations localizations,
    required bool enabled,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final effectiveValue = _onlinePronunciationLanguages.containsKey(value)
        ? value
        : "";
    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: localizations.onlinePronunciationLanguage,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        DropdownMenuItem(
          value: "",
          child: Text(localizations.onlinePronunciationFollowSystemLanguage),
        ),
        for (final entry in _onlinePronunciationLanguages.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: enabled
          ? (language) {
              if (language != null) {
                onChanged(language);
              }
            }
          : null,
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
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue:
              settings.ttsEngine ??
              (ttsEngines.isNotEmpty ? ttsEngines.first : null),
          isExpanded: true,
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

/// Linux TTS settings: backend status, a voice picker populated
/// from the active backend, and a refresh affordance.
///
/// The voice list comes from [LinuxTtsDriver.voices], already
/// language-filtered by the service for [settings.ttsLanguage]; it
/// is capped so a long espeak voice list stays usable in a
/// dropdown. The saved voice is [settings.linuxTtsVoice]; when it
/// is unset (or no longer offered) the default option is shown and
/// the backend picks its default voice for the language. Detection
/// failures leave the no-backend hint in place rather than
/// erroring: TTS simply falls through to unavailable at speak time.
class LinuxTtsSettings extends StatefulWidget {
  const LinuxTtsSettings({super.key});

  @override
  State<LinuxTtsSettings> createState() => _LinuxTtsSettingsState();
}

class _LinuxTtsSettingsState extends State<LinuxTtsSettings> {
  /// Voices shown in the picker; capped for dropdown usability.
  static const _maxVoices = 50;

  LinuxTtsAvailability? _availability;
  List<LinuxVoice> _voices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    LinuxTtsAvailability? availability;
    List<LinuxVoice> voices = [];
    try {
      availability = await linuxTtsDriver.detect(refresh: true);
      voices = await linuxTtsDriver.voices(language: settings.ttsLanguage);
    } catch (_) {
      // Detection/listing failure: keep the no-backend state.
    }
    if (!mounted) return;
    setState(() {
      _availability = availability;
      _voices = voices.take(_maxVoices).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final helperStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final availability = _availability;
    final savedVoice = settings.linuxTtsVoice;
    final effectiveValue =
        savedVoice != null && _voices.any((voice) => voice.id == savedVoice)
        ? savedVoice
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          availability == null || !availability.any
              ? localizations.linuxTtsNoBackend
              : localizations.linuxTtsBackends(
                  [
                    if (availability.ssip)
                      localizations.linuxTtsBackendSpeechDispatcher,
                    if (availability.espeak)
                      localizations.linuxTtsBackendEspeak,
                  ].join(", "),
                ),
          style: helperStyle,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          // Rebuild the field when the effective selection changes
          // (e.g. the saved voice only becomes known once the async
          // voice list loads): FormField otherwise keeps its first
          // initialValue forever.
          key: ValueKey(effectiveValue),
          initialValue: effectiveValue,
          // Voice names from espeak can be long, so let the field fill the
          // available width and shorten the label instead of overflowing.
          isExpanded: true,
          decoration: InputDecoration(
            labelText: localizations.linuxTtsVoice,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(localizations.linuxTtsVoiceDefault),
            ),
            for (final voice in _voices)
              DropdownMenuItem(
                value: voice.id,
                child: Text(voice.displayName, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (voice) {
            settings.setLinuxTtsVoice(voice);
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(localizations.linuxTtsRefreshVoices),
            onPressed: _loading ? null : _load,
          ),
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
    final locale = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final favorites = _favorites();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleText(locale.ttsLanguages),
        const SizedBox(height: 12),
        for (final language in favorites)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            dense: true,
            selected: language == settings.ttsLanguage,
            selectedTileColor: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Checkbox(
              value: true,
              onChanged: favorites.length > 1
                  ? (_) => _removeFavorite(language)
                  : null,
            ),
            title: Text(language),
            trailing: language == settings.ttsLanguage
                ? Icon(Icons.check, color: colorScheme.primary)
                : null,
            onTap: () => _setCurrent(language),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addFavorite(context),
            icon: const Icon(Icons.add),
            label: Text(locale.ttsLanguages),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// The favorites list, seeded from the current voice so settings created
  /// before this feature still show one selectable entry.
  List<String> _favorites() {
    if (settings.ttsLanguageFavorites.isNotEmpty) {
      return settings.ttsLanguageFavorites;
    }
    final current = settings.ttsLanguage ?? _defaultLanguage();
    return current.isEmpty ? [] : [current];
  }

  Future<void> _setCurrent(String language) async {
    await settings.setTTSLanguage(language);
    if (!Platform.isLinux) {
      await flutterTts.setLanguage(language);
    }
  }

  Future<void> _removeFavorite(String language) async {
    final remaining = _favorites().where((item) => item != language).toList();
    if (remaining.isEmpty) return;
    await settings.setTTSLanguageFavorites(remaining);
  }

  Future<void> _addFavorite(BuildContext context) async {
    final currentFavorites = _favorites();
    final available = ttsLanguages
        .where((item) => !currentFavorites.contains(item))
        .toList();
    if (available.isEmpty) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.ttsLanguages),
        children: [
          for (final language in available)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(language),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(language),
              ),
            ),
        ],
      ),
    );
    if (selected == null) return;
    await settings.setTTSLanguageFavorites([...currentFavorites, selected]);
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
            // Linux speech reads the saved settings on every
            // utterance, so there is no live instance to update;
            // flutter_tts is never touched on Linux.
            if (!Platform.isLinux) {
              await flutterTts.setSpeechRate(value);
            }
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
            if (!Platform.isLinux) {
              await flutterTts.setPitch(value);
            }
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text(localizations.ttsPreview),
            onPressed: () async {
              if (Platform.isLinux) {
                // Preview through the Linux path (SSIP, then the
                // espeak WAV fallback) with the current settings.
                await TtsHelper.toggleSpeak(localizations.ttsPreviewText);
                return;
              }
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

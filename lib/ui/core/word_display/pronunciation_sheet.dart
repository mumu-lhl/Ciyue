import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

/// Opens the pronunciation settings sheet from the word page.
///
/// Long-pressing the speaker button brings the controls that are usually
/// buried in Settings next to the word being looked up: the TTS voice, the
/// audio pack order and the online pronunciation sources.
Future<void> showPronunciationSettingsSheet(BuildContext context, String word) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _PronunciationSettingsSheet(word: word),
  );
}

class _PronunciationSettingsSheet extends ConsumerWidget {
  const _PronunciationSettingsSheet({required this.word});

  final String word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    ref.watch(settingsProvider);
    ref.watch(audioModelProvider);

    return FractionallySizedBox(
      heightFactor: 0.8,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.record_voice_over,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    locale.audioSettings,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionTitle(text: locale.ttsLanguages),
            ..._buildTtsLanguages(context, ref),
            const SizedBox(height: 24),
            _SectionTitle(text: locale.pronunciation),
            ..._buildAudioPacks(context, ref),
            const SizedBox(height: 24),
            _SectionTitle(text: locale.onlinePronunciation),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              dense: true,
              title: Text(locale.onlinePronunciationWiktionary),
              value: settings.wiktionaryPronunciationEnabled,
              onChanged: (value) =>
                  settings.setWiktionaryPronunciationEnabled(value),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              dense: true,
              title: Text(locale.onlinePronunciationForvo),
              value: settings.forvoPronunciationEnabled,
              onChanged: (value) =>
                  settings.setForvoPronunciationEnabled(value),
            ),
          ],
        ),
      ),
    );
  }

  /// The favorites list, seeded from the current voice so settings created
  /// before this feature still show one selectable entry.
  List<Widget> _buildTtsLanguages(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final favorites = settings.ttsLanguageFavorites;
    final current = settings.ttsLanguage;
    final languages = favorites.isNotEmpty
        ? favorites
        : [if (current != null && current.isNotEmpty) current else "en-US"];

    return [
      for (final language in languages)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          dense: true,
          selected: language == current,
          selectedTileColor: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(
            Icons.record_voice_over,
            size: 20,
            color: colorScheme.primary,
          ),
          title: Text(language),
          trailing: language == current
              ? Icon(Icons.check, color: colorScheme.primary)
              : null,
          onTap: () async {
            await settings.setTTSLanguage(language);
            if (!Platform.isLinux) {
              await flutterTts.setLanguage(language);
            }
            await ref.read(audioModelProvider).playWord(word);
          },
        ),
    ];
  }

  /// The audio packs in lookup order, with arrows that persist the new
  /// order through [MddAudioListDao.updateOrder].
  List<Widget> _buildAudioPacks(BuildContext context, WidgetRef ref) {
    final packs = ref.read(audioModelProvider).mddAudioList;
    if (packs.isEmpty) return const [];

    return [
      for (var index = 0; index < packs.length; index++)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          dense: true,
          title: Text(packs[index].title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: const Icon(Icons.arrow_upward),
                onPressed: index == 0 ? null : () => _movePack(ref, index, -1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: const Icon(Icons.arrow_downward),
                onPressed: index == packs.length - 1
                    ? null
                    : () => _movePack(ref, index, 1),
              ),
            ],
          ),
        ),
    ];
  }

  Future<void> _movePack(WidgetRef ref, int index, int delta) async {
    final audioModel = ref.read(audioModelProvider);
    final packs = audioModel.mddAudioList;
    final target = index + delta;
    if (target < 0 || target >= packs.length) return;

    final current = packs[index];
    final neighbor = packs[target];
    await mddAudioListDao.updateOrder(current.id, neighbor.order);
    await mddAudioListDao.updateOrder(neighbor.id, current.order);
    await audioModel.init();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

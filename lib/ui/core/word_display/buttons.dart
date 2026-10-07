import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/backup.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/tags_list.dart";
import "package:ciyue/ui/core/word_display/ai_widgets.dart";
import "package:ciyue/ui/core/word_display/audio_waveform.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";

Future<void> autoExportWordbook() async {
  if (settings.autoExport &&
      (settings.exportDirectory != null || settings.exportPath != null)) {
    Backup.export(true);
  }
}

Future<void> toggleStarWord(
  BuildContext context,
  String word, {
  required bool currentStared,
  required VoidCallback onUpdated,
}) async {
  final locale = AppLocalizations.of(context)!;
  final wordbookModel = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(wordbookModelProvider);

  Future<void> star() async {
    if (currentStared) {
      await wordbookModel.delete(word);
    } else {
      await wordbookModel.add(word);
    }

    await autoExportWordbook();
    onUpdated();
  }

  if (wordbookTagsDao.tagExist) {
    final tagsOfWord = await wordbookDao.tagsOfWord(word),
        tags = await wordbookTagsDao.getAllTags();

    final toAdd = <int>[], toDel = <int>[];

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(locale.tags),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TagsList(
                tags: tags,
                tagsOfWord: tagsOfWord,
                toAdd: toAdd,
                toDel: toDel,
              ),
              if (currentStared)
                ListTile(
                  title: Text(locale.remove),
                  leading: const Icon(Icons.delete),
                  onTap: () async {
                    context.pop();
                    await wordbookModel.removeWordWithAllTags(word);
                    await autoExportWordbook();
                    onUpdated();
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(locale.cancel),
              onPressed: () {
                context.pop();
              },
            ),
            TextButton(
              child: Text(locale.confirm),
              onPressed: () async {
                context.pop();
                if (!currentStared) {
                  await wordbookModel.add(word);
                }

                if (toAdd.isNotEmpty) {
                  for (final tag in toAdd) {
                    await wordbookModel.add(word, tag: tag);
                  }
                }

                if (toDel.isNotEmpty) {
                  for (final tag in toDel) {
                    await wordbookModel.delete(word, tag: tag);
                  }
                }

                await autoExportWordbook();
                onUpdated();
              },
            ),
          ],
        );
      },
    );
  } else {
    await star();
  }
}

Future<void> playWordPronunciation(BuildContext context, String word) async {
  final audioModel = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(audioModelProvider);
  if (audioModel.isWordPlaying(word)) {
    await audioModel.stopAudio();
  } else {
    await audioModel.playWord(word);
  }
}

class Button extends ConsumerStatefulWidget {
  final String word;
  final bool showAIButtons;

  const Button({super.key, required this.word, this.showAIButtons = false});

  @override
  ConsumerState<Button> createState() => _ButtonState();
}

class _ButtonState extends ConsumerState<Button> {
  Future<bool>? stared;

  @override
  void initState() {
    super.initState();
    stared = wordbookDao.wordExist(widget.word);
  }

  @override
  void didUpdateWidget(covariant Button oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.word != oldWidget.word) {
      checkStared();
    }
  }

  void checkStared() {
    setState(() {
      stared = wordbookDao.wordExist(widget.word);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.showAIButtons) RefreshAIExplainButton(word: widget.word),
        if (widget.showAIButtons)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: EditAIExplainButton(
              word: widget.word,
              initialExplanation:
                  ref
                      .watch(aiExplanationModelProvider(widget.word))
                      .explanation ??
                  "",
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: buildReadLoudlyButton(context, widget.word),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: buildStarButton(context),
        ),
      ],
    );
  }

  Widget buildReadLoudlyButton(BuildContext context, String word) {
    final colorScheme = Theme.of(context).colorScheme;
    final audioModel = ref.watch(audioModelProvider);
    final isPlaying = audioModel.isWordPlaying(word);

    return PulsingFab(
      isPulsing: isPlaying,
      ringColor: colorScheme.primary,
      child: FloatingActionButton.small(
        heroTag: "readLoudly_$word",
        tooltip: AppLocalizations.of(context)!.readLoudly,
        foregroundColor: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isPlaying
              ? AudioWaveformIcon(
                  key: const ValueKey("playing"),
                  color: colorScheme.primary,
                  size: 20,
                )
              : const Icon(Icons.volume_up, key: ValueKey("idle")),
        ),
        onPressed: () => playWordPronunciation(context, word),
      ),
    );
  }

  Widget buildStarButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = AppLocalizations.of(context)!;

    return FutureBuilder(
      future: stared,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (!snapshot.hasData) {
          return FloatingActionButton.small(
            heroTag: "star_${widget.word}",
            tooltip: locale.wordBook,
            foregroundColor: colorScheme.primary,
            backgroundColor: colorScheme.surface,
            child: const Icon(Icons.star_outline),
            onPressed: () {},
          );
        }

        return FloatingActionButton.small(
          heroTag: "star_${widget.word}",
          tooltip: locale.wordBook,
          foregroundColor: colorScheme.primary,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(snapshot.data! ? Icons.star : Icons.star_outline),
          onPressed: () => toggleStarWord(
            context,
            widget.word,
            currentStared: snapshot.data!,
            onUpdated: checkStared,
          ),
        );
      },
    );
  }
}

class WordStarIconButton extends StatefulWidget {
  final String word;

  const WordStarIconButton({super.key, required this.word});

  @override
  State<WordStarIconButton> createState() => _WordStarIconButtonState();
}

class _WordStarIconButtonState extends State<WordStarIconButton> {
  Future<bool>? stared;

  @override
  void initState() {
    super.initState();
    stared = wordbookDao.wordExist(widget.word);
  }

  @override
  void didUpdateWidget(covariant WordStarIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.word != oldWidget.word) {
      checkStared();
    }
  }

  void checkStared() {
    setState(() {
      stared = wordbookDao.wordExist(widget.word);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return FutureBuilder<bool>(
      future: stared,
      builder: (context, snapshot) {
        final isStared = snapshot.data ?? false;
        return IconButton(
          tooltip: locale.wordBook,
          icon: Icon(
            isStared ? Icons.star : Icons.star_outline,
            color: isStared ? Theme.of(context).colorScheme.primary : null,
          ),
          onPressed: snapshot.hasData
              ? () => toggleStarWord(
                  context,
                  widget.word,
                  currentStared: isStared,
                  onUpdated: checkStared,
                )
              : null,
        );
      },
    );
  }
}

class WordPronounceIconButton extends ConsumerWidget {
  final String word;

  const WordPronounceIconButton({super.key, required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final audioModel = ref.watch(audioModelProvider);
    final isPlaying = audioModel.isWordPlaying(word);
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: locale.readLoudly,
      icon: isPlaying
          ? AudioWaveformIcon(
              key: const ValueKey("playing"),
              color: colorScheme.primary,
              size: 20,
            )
          : const Icon(Icons.volume_up, key: ValueKey("idle")),
      onPressed: () => playWordPronunciation(context, word),
    );
  }
}

class RefreshAIExplainIconButton extends ConsumerWidget {
  final String word;

  const RefreshAIExplainIconButton({super.key, required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: AppLocalizations.of(context)!.update,
      icon: const Icon(Icons.refresh),
      onPressed: () {
        ref.read(aiExplanationModelProvider(word)).refreshExplanation(word);
      },
    );
  }
}

class EditAIExplainIconButton extends ConsumerWidget {
  final String word;

  const EditAIExplainIconButton({super.key, required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: AppLocalizations.of(context)!.editAIExplanation,
      icon: const Icon(Icons.edit),
      onPressed: () {
        final model = ref.read(aiExplanationModelProvider(word));
        context.push(
          "/edit_ai_explanation",
          extra: {
            "word": word,
            "initialExplanation": model.explanation ?? "",
            "aiExplanationModel": model,
          },
        );
      },
    );
  }
}

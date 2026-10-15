import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/date_divider.dart";
import "package:ciyue/ui/core/word_display.dart";
import "package:ciyue/ui/pages/main/wordbook/app_bar.dart";
import "package:ciyue/ui/pages/main/wordbook/floating_action_buttons.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:ciyue/ui/pages/flashcards/overview_card.dart";
import "package:ciyue/utils.dart";

class WordBookScreen extends ConsumerWidget {
  const WordBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(wordbookModelProvider.select((model) => model.selectedDate));
    final isDesktop = isLargeScreen(context);

    if (isDesktop) {
      final selectedWord = ref.watch(
        wordbookModelProvider.select((model) => model.selectedWord),
      );

      return Scaffold(
        appBar: const WordbookAppBar(),
        body: Row(
          children: [
            const SizedBox(width: 360, child: WordViewWithTagsClips()),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: selectedWord != null && selectedWord.isNotEmpty
                  ? KeyedSubtree(
                      key: ValueKey(selectedWord),
                      child: WordDisplay(
                        word: selectedWord,
                        showBackButton: false,
                      ),
                    )
                  : Center(
                      child: Text(
                        AppLocalizations.of(context)!.empty,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return const Scaffold(
      appBar: WordbookAppBar(),
      body: WordViewWithTagsClips(),
      floatingActionButton: WordbookFloatingActionButtons(),
    );
  }
}

class WordView extends ConsumerWidget {
  final Future<List<WordbookData>> allWords;

  const WordView({super.key, required this.allWords});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: allWords,
      builder:
          (BuildContext context, AsyncSnapshot<List<WordbookData>> snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return FutureBuilder(
                future: ref.read(wordbookModelProvider).tags,
                builder: (context, tagSnapshot) {
                  if (tagSnapshot.hasData && tagSnapshot.data!.isNotEmpty) {
                    return const Expanded(child: SizedBox());
                  }
                  return Expanded(
                    child: Center(
                      child: Text(AppLocalizations.of(context)!.empty),
                    ),
                  );
                },
              );
            }

            // Build a flat list of items (dates and words), not widgets.
            // ListView.builder only instantiates widgets for visible items.
            final items = <Object>[];
            var lastDate = DateTime(
              snapshot.data![0].createdAt.year,
              snapshot.data![0].createdAt.month,
              snapshot.data![0].createdAt.day,
            );
            items.add(lastDate);
            for (final data in snapshot.data!) {
              final date = DateTime(
                data.createdAt.year,
                data.createdAt.month,
                data.createdAt.day,
              );
              if (date != lastDate) {
                lastDate = date;
                items.add(date);
              }
              items.add(data);
            }

            final allWordsList = snapshot.data!;
            return Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  if (item is DateTime) {
                    return DateDivider(date: item);
                  }
                  final data = item as WordbookData;
                  return _WordListTile(data: data, allWords: allWordsList);
                },
              ),
            );
          },
    );
  }
}

/// Single word tile extracted for ListView.builder (only visible items built).
class _WordListTile extends ConsumerWidget {
  final WordbookData data;
  final List<WordbookData> allWords;

  const _WordListTile({required this.data, required this.allWords});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMultiSelectMode = ref.watch(
      wordbookModelProvider.select((m) => m.isMultiSelectMode),
    );
    final isSelected = ref.watch(
      wordbookModelProvider.select((m) => m.selectedWords.contains(data)),
    );
    final selectedWord = ref.watch(
      wordbookModelProvider.select((m) => m.selectedWord),
    );
    final model = ref.read(wordbookModelProvider);

    final isDesktop = isLargeScreen(context);
    final isWordSelected = !isMultiSelectMode && selectedWord == data.word;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: isWordSelected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer
            .withValues(alpha: 0.45),
        leading: isMultiSelectMode
            ? Checkbox(
                value: isSelected,
                onChanged: (value) {
                  model.selectWord(data);
                },
              )
            : Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bookmark_outline_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
        title: Text(
          data.word,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: isMultiSelectMode
            ? null
            : const Icon(Icons.chevron_right_rounded, size: 18),
        onLongPress: () {
          if (!isMultiSelectMode) {
            model.toggleMultiSelectMode();
            model.selectWord(data);
          }
        },
        onTap: () async {
          if (isMultiSelectMode) {
            model.selectWord(data);
          } else if (isDesktop) {
            model.selectedWord = data.word;
          } else {
            if (context.mounted) {
              final words = allWords.map((e) => e.word).toList();
              final index = allWords.indexOf(data);
              context.push(
                "/word/${Uri.encodeComponent(data.word)}",
                extra: WordListContext(
                  words: words,
                  initialIndex: index >= 0 ? index : 0,
                ),
              );
            }
          }
        },
      ),
    );
  }
}

class WordViewWithTagsClips extends ConsumerStatefulWidget {
  const WordViewWithTagsClips({super.key});

  @override
  ConsumerState<WordViewWithTagsClips> createState() =>
      _WordViewWithTagsClipsState();
}

class _WordViewWithTagsClipsState extends ConsumerState<WordViewWithTagsClips> {
  @override
  void initState() {
    super.initState();

    final wordbookModel = ref.read(wordbookModelProvider);
    wordbookModel.allWords = wordbookDao.getAllWordsWithTag();
    wordbookModel.tags = wordbookTagsDao.getAllTags();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTag = ref.watch(
      wordbookModelProvider.select((m) => m.selectedTag),
    );
    final tagsFuture = ref.watch(wordbookModelProvider.select((m) => m.tags));
    final allWords = ref.watch(wordbookModelProvider.select((m) => m.allWords));
    final model = ref.read(wordbookModelProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlashcardOverviewCard(key: ValueKey(selectedTag), tag: selectedTag),
        FutureBuilder(
          future: tagsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              final choiceChips = <Widget>[];
              final tagsMap = <int, WordbookTag>{};
              for (final tag in snapshot.data!) {
                tagsMap[tag.id] = tag;
              }

              for (final tagId in wordbookTagsDao.tagsOrder) {
                final tag = tagsMap[tagId];
                if (tag == null) continue;

                choiceChips.add(
                  ChoiceChip(
                    label: Text(tag.tag),
                    selected: selectedTag == tag.id,
                    onSelected: (selected) {
                      model.updateSelectedTag(selected ? tag.id : null);
                      model.updateWordList();
                    },
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: choiceChips,
                ),
              );
            }

            return const Wrap();
          },
        ),
        WordView(allWords: allWords),
      ],
    );
  }
}

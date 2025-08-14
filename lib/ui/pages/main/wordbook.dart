import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/date_divider.dart";
import "package:ciyue/ui/pages/main/wordbook/app_bar.dart";
import "package:ciyue/ui/pages/main/wordbook/floating_action_buttons.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

class WordBookScreen extends StatefulWidget {
  const WordBookScreen({super.key});

  @override
  State<WordBookScreen> createState() => _WordBookScreenState();
}

class WordView extends StatelessWidget {
  final Future<List<WordbookData>> allWords;

  const WordView({super.key, required this.allWords});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: allWords,
        builder:
            (BuildContext context, AsyncSnapshot<List<WordbookData>> snapshot) {
          final list = <Widget>[];
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final firstWord = snapshot.data![0];
            var lastDate = DateTime(firstWord.createdAt.year,
                firstWord.createdAt.month, firstWord.createdAt.day);
            list.add(DateDivider(
              date: lastDate,
            ));

            for (final data in snapshot.data!) {
              final date = DateTime(data.createdAt.year, data.createdAt.month,
                  data.createdAt.day);

              if (date != lastDate) {
                lastDate = date;
                list.add(DateDivider(
                  date: date,
                ));
              }

              list.add(
                Selector<WordbookModel, (bool, bool)>(
                  selector: (context, model) => (
                    model.isMultiSelectMode,
                    model.selectedWords.contains(data)
                  ),
                  builder: (context, value, child) {
                    final isMultiSelectMode = value.$1;
                    final isSelected = value.$2;
                    final model = context.read<WordbookModel>();

                    return ListTile(
                      leading: isMultiSelectMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                model.selectWord(data);
                              },
                            )
                          : null,
                      title: Text(data.word),
                      onLongPress: () {
                        if (!isMultiSelectMode) {
                          model.toggleMultiSelectMode();
                          model.selectWord(data);
                        }
                      },
                      onTap: () async {
                        if (isMultiSelectMode) {
                          model.selectWord(data);
                        } else {
                          if (context.mounted) {
                            context.push("/word", extra: {"word": data.word});
                          }
                        }
                      },
                    );
                  },
                ),
              );
            }
          }

          if (list.isEmpty) {
            return FutureBuilder(
              future: context.read<WordbookModel>().tags,
              builder: (context, tagSnapshot) {
                if (tagSnapshot.hasData && tagSnapshot.data!.isNotEmpty) {
                  return const Expanded(child: SizedBox());
                }
                return Expanded(
                    child: Center(
                        child: Text(AppLocalizations.of(context)!.empty)));
              },
            );
          } else {
            return Expanded(child: ListView(children: list));
          }
        });
  }
}

class WordViewWithTagsClips extends StatefulWidget {
  const WordViewWithTagsClips({super.key});

  @override
  State<WordViewWithTagsClips> createState() => _WordViewWithTagsClipsState();
}

class _WordBookScreenState extends State<WordBookScreen> {
  @override
  Widget build(BuildContext context) {
    context.select<WordbookModel, DateTime?>((model) => model.selectedDate);

    return const Scaffold(
      appBar: WordbookAppBar(),
      body: WordViewWithTagsClips(),
      floatingActionButton: WordbookFloatingActionButtons(),
    );
  }
}

class _WordViewWithTagsClipsState extends State<WordViewWithTagsClips> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Selector<WordbookModel, (Future<List<WordbookTag>>, int?)>(
          selector: (context, model) => (model.tags, model.selectedTag),
          builder: (context, value, child) {
            final tagsFuture = value.$1;
            final selectedTag = value.$2;
            final model = context.read<WordbookModel>();

            return FutureBuilder(
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

                    choiceChips.add(ChoiceChip(
                      label: Text(tag.tag),
                      selected: selectedTag == tag.id,
                      onSelected: (selected) {
                        model.updateSelectedTag(selected ? tag.id : null);
                        model.updateWordList();
                      },
                    ));
                  }

                  return Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Wrap(
                        spacing: 8.0, runSpacing: 4.0, children: choiceChips),
                  );
                }

                return const Wrap();
              },
            );
          },
        ),
        Selector<WordbookModel, Future<List<WordbookData>>>(
          selector: (context, model) => model.allWords,
          builder: (context, allWords, child) => WordView(
            allWords: allWords,
          ),
        )
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    final wordbookModel = context.read<WordbookModel>();
    wordbookModel.allWords = wordbookDao.getAllWordsWithTag();
    wordbookModel.tags = wordbookTagsDao.getAllTags();
  }
}

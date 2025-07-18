import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/date_divider.dart";
import "package:ciyue/ui/core/text_buttons.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

class MonthPickerDialog extends StatefulWidget {
  const MonthPickerDialog({super.key});

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class MoreOptionsDialog extends StatefulWidget {
  const MoreOptionsDialog({super.key});

  @override
  State<MoreOptionsDialog> createState() => _MoreOptionsDialogState();
}

class TagListDialog extends StatefulWidget {
  final List<WordbookTag> tagsDisplay;

  final Future<void> Function(BuildContext context) buildAddTag;

  const TagListDialog({
    super.key,
    required this.tagsDisplay,
    required this.buildAddTag,
  });

  @override
  State<TagListDialog> createState() => _TagListDialogState();
}

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

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int selectedYear;
  late int selectedMonth;
  late final int initialYear;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: 300,
        height: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_left),
                  onPressed: () {
                    setState(() {
                      selectedYear--;
                    });
                  },
                ),
                Text(
                  selectedYear.toString(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: Icon(Icons.arrow_right),
                  onPressed: () {
                    setState(() {
                      selectedYear++;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).pop(
                        DateTime(selectedYear, month),
                      );
                    },
                    child: Container(
                      margin: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: initialYear == selectedYear &&
                                month == selectedMonth
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          month.toString(),
                          style: TextStyle(
                            color: initialYear == selectedYear &&
                                    month == selectedMonth
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final initialDate =
        context.read<WordbookModel>().selectedDate ?? DateTime.now();
    selectedYear = initialDate.year;
    selectedMonth = initialDate.month;
    initialYear = initialDate.year;
  }
}

class _MoreOptionsDialogState extends State<MoreOptionsDialog> {
  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(AppLocalizations.of(context)!.more),
      children: [
        SimpleDialogOption(
          child: CheckboxListTile(
            value: settings.skipTaggedWord,
            onChanged: (value) async {
              if (value != null) {
                settings.skipTaggedWord = value;
                await prefs.setBool("skipTaggedWord", value);
                setState(() {});
                if (context.mounted) {
                  final wordbookModel = context.read<WordbookModel>();
                  wordbookModel.updateWordList();
                }
              }
            },
            title: Text(AppLocalizations.of(context)!.skipTaggedWord),
          ),
        ),
      ],
    );
  }
}

class _TagListDialogState extends State<TagListDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.tagList),
      content: SizedBox(
        height: 300,
        width: 300,
        child: ReorderableListView(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          onReorder: (oldIndex, newIndex) async {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }

            final tag = widget.tagsDisplay.removeAt(oldIndex);
            widget.tagsDisplay.insert(newIndex, tag);

            wordbookTagsDao.tagsOrder =
                widget.tagsDisplay.map((e) => e.id).toList();
            await wordbookTagsDao.updateTagsOrder();

            if (context.mounted) {
              final wordbookModel = context.read<WordbookModel>();
              wordbookModel.updateTags();
            }
            setState(() {});
          },
          children: widget.tagsDisplay
              .map((tag) => ListTile(
                    key: ValueKey(tag.id),
                    title: Text(tag.tag),
                    leading: ReorderableDragStartListener(
                      index: widget.tagsDisplay.indexOf(tag),
                      child: Icon(Icons.drag_handle),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () async {
                        await wordbookTagsDao.removeTag(tag.id);
                        await wordbookTagsDao.existTag();

                        if (context.mounted) {
                          final wordbookModel = context.read<WordbookModel>();
                          wordbookModel.updateTags();
                        }

                        if (context.mounted) context.pop();
                      },
                    ),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextCloseButton(),
        TextButton(
          child: Text(AppLocalizations.of(context)!.add),
          onPressed: () async {
            context.pop();
            await widget.buildAddTag(context);
          },
        ),
      ],
    );
  }
}

class _WordBookScreenState extends State<WordBookScreen> {
  Future<void> addTag(BuildContext context, String tagName) async {
    await wordbookTagsDao.addTag(tagName);
    await wordbookTagsDao.existTag();

    if (context.mounted) {
      context.read<WordbookModel>().updateTags();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.select<WordbookModel, DateTime?>((model) => model.selectedDate);
    final wordbookModel = context.read<WordbookModel>();

    return Scaffold(
        appBar: buildAppBar(context),
        body: WordViewWithTagsClips(),
        floatingActionButton:
            Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (wordbookModel.selectedDate != null)
            FloatingActionButton(
              onPressed: () {
                wordbookModel.selectedDate = null;
                wordbookModel.updateWordList();
              },
              child: const Icon(Icons.clear),
            ),
          SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () async {
              final DateTime? picked = await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return MonthPickerDialog();
                },
              );
              if (picked != null) {
                if (context.mounted) {
                  wordbookModel.selectedDate = picked;
                  wordbookModel.updateWordList();
                }
              }
            },
            child: const Icon(Icons.calendar_month),
          ),
        ]));
  }

  Future<void> buildAddTag(BuildContext context) async {
    final locale = AppLocalizations.of(context)!;

    await showDialog(
        context: context,
        builder: (BuildContext context) {
          final textController = TextEditingController();

          return AlertDialog(
            title: Text(locale.addTag),
            content: TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: locale.tagName,
              ),
              controller: textController,
              onSubmitted: (String tagName) async {
                await addTag(context, tagName);
              },
            ),
            actions: [
              TextCloseButton(),
              TextButton(
                child: Text(locale.add),
                onPressed: () async {
                  await addTag(context, textController.text);
                },
              )
            ],
          );
        });
  }

  Future<void> _showDeleteConfirmationDialog(WordbookModel model) async {
    final count = model.selectedWords.length;
    final locale = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locale.confirmDelete),
        content: Text(locale.confirmDeleteWords(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(locale.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(locale.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await model.deleteSelectedWords();
    }
  }

  AppBar buildAppBar(BuildContext context) {
    final model = context.read<WordbookModel>();

    return AppBar(
      actions: [
        Selector<WordbookModel, (bool, bool)>(
          selector: (context, model) =>
              (model.isMultiSelectMode, model.selectedWords.isEmpty),
          builder: (context, value, child) {
            final isMultiSelectMode = value.$1;
            final isSelectedWordsEmpty = value.$2;

            if (isMultiSelectMode) {
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      model.toggleMultiSelectMode();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: isSelectedWordsEmpty
                        ? null
                        : () {
                            _showDeleteConfirmationDialog(model);
                          },
                  ),
                ],
              );
            } else {
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.label_outline),
                    onPressed: () async {
                      final tags = await model.tags;

                      if (!context.mounted) return;

                      if (tags.isEmpty) {
                        await buildAddTag(context);
                      } else {
                        await buildTagsList(context, tags);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () async {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return const MoreOptionsDialog();
                        },
                      );
                    },
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> buildTagsList(
      BuildContext context, List<WordbookTag> tags) async {
    if (!context.mounted) return;

    await showDialog(
        context: context,
        builder: (BuildContext context) {
          final tagsMap = <int, WordbookTag>{};
          for (final tag in tags) {
            tagsMap[tag.id] = tag;
          }
          final tagListTile = <Widget>[];

          final tagsDisplay = wordbookTagsDao.tagsOrder.isEmpty
              ? tags
              : wordbookTagsDao.tagsOrder.map((e) => tagsMap[e]!).toList();

          for (final tag in tagsDisplay) {
            tagListTile.add(ListTile(
              key: ValueKey(tag.id),
              title: Text(tag.tag),
              leading: ReorderableDragStartListener(
                index: tagsDisplay.indexOf(tag),
                child: Icon(Icons.drag_handle),
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () async {
                  await wordbookTagsDao.removeTag(tag.id);
                  await wordbookTagsDao.existTag();

                  if (context.mounted) {
                    final wordbookModel = context.read<WordbookModel>();
                    wordbookModel.updateTags();

                    context.pop();
                  }
                },
              ),
            ));
          }

          return TagListDialog(
              tagsDisplay: tagsDisplay, buildAddTag: buildAddTag);
        });
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

                return Wrap();
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

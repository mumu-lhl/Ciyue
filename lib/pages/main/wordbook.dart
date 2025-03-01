import "package:ciyue/database/app.dart";
import "package:ciyue/main.dart";
import "package:ciyue/settings.dart";
import "package:ciyue/widget/text_buttons.dart";
import "package:ciyue/widget/date_divider.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

VoidCallback? _refreshScreen;
VoidCallback? _refreshTagsAndWords;

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

class _WordBookScreenState extends State<WordBookScreen> {
  @override
  void initState() {
    super.initState();
    _refreshScreen = () {
      setState(() {});
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: buildAppBar(context),
        body: WordViewWithTagsClips(),
        floatingActionButton:
            Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (_WordViewWithTagsClipsState._selectedDate != null)
            FloatingActionButton(
              onPressed: () {
                _WordViewWithTagsClipsState._selectedDate = null;
                _refreshTagsAndWords!();
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
                _WordViewWithTagsClipsState._selectedDate = picked;
                _refreshTagsAndWords!();
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
              decoration: InputDecoration(
                labelText: locale.tagName,
              ),
              controller: textController,
            ),
            actions: [
              TextCloseButton(),
              TextButton(
                child: Text(locale.add),
                onPressed: () async {
                  await wordbookTagsDao.addTag(textController.text);
                  await wordbookTagsDao.existTag();

                  _refreshTagsAndWords!();

                  if (context.mounted) {
                    context.pop();
                  }
                },
              )
            ],
          );
        });
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      actions: [
        IconButton(
          icon: Icon(Icons.bookmark),
          onPressed: () async {
            final tags = await wordbookTagsDao.getAllTags();

            if (!context.mounted) return;

            if (tags.isEmpty) {
              await buildAddTag(context);
            } else {
              await buildTagsList(context, tags);
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.more_vert),
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

                  _refreshTagsAndWords!();

                  if (context.mounted) context.pop();
                },
              ),
            ));
          }

          return TagListDialog(
              tagsDisplay: tagsDisplay, buildAddTag: buildAddTag);
        });
  }
}

class WordView extends StatelessWidget {
  final Future<List<WordbookData>> allWords;
  final Future<List<WordbookTag>> tags;

  const WordView({
    super.key,
    required this.allWords,
    required this.tags,
  });

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

              list.add(ListTile(
                title: Text(data.word),
                onTap: () async {
                  if (context.mounted) {
                    context.push("/word", extra: {"word": data.word});
                  }
                },
              ));
            }
          }

          if (list.isEmpty) {
            return FutureBuilder(
              future: tags,
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
                _refreshTagsAndWords!();
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

            _refreshTagsAndWords!();
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

                        _refreshTagsAndWords!();

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

class MonthPickerDialog extends StatefulWidget {
  const MonthPickerDialog({super.key});

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int selectedYear;
  late int selectedMonth;
  late final int initialYear;

  @override
  void initState() {
    super.initState();
    final initialDate =
        _WordViewWithTagsClipsState._selectedDate ?? DateTime.now();
    selectedYear = initialDate.year;
    selectedMonth = initialDate.month;
    initialYear = initialDate.year;
  }

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
}

class _WordViewWithTagsClipsState extends State<WordViewWithTagsClips> {
  late Future<List<WordbookData>> allWords;
  late Future<List<WordbookTag>> tags;
  static DateTime? _selectedDate;

  int? selectedTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder(
            future: tags,
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
                      setState(() {
                        selectedTag = selected ? tag.id : null;
                        final skipTaggedWord =
                            selectedTag == null && settings.skipTaggedWord;
                        allWords = wordbookDao.getAllWordsWithTag(
                            tag: selectedTag, skipTagged: skipTaggedWord);
                      });
                    },
                  ));
                }

                return Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Wrap(spacing: 8.0, runSpacing: 4.0, children: choiceChips),
                );
              }

              return Wrap();
            }),
        WordView(allWords: allWords, tags: tags),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    updateWordList();
    tags = wordbookTagsDao.getAllTags();

    _refreshTagsAndWords = refresh;
  }

  void updateWordList() {
    if (_selectedDate != null) {
      allWords = wordbookDao.getWordsByYearMonth(
        _selectedDate!.year,
        _selectedDate!.month,
        tag: selectedTag,
      );
    } else {
      allWords = wordbookDao.getAllWordsWithTag(
        tag: selectedTag,
        skipTagged: settings.skipTaggedWord,
      );
    }
  }

  void refresh() {
    setState(() {
      updateWordList();
      tags = wordbookTagsDao.getAllTags();
      _refreshScreen!();
    });
  }
}

import "package:ciyue/database/app.dart";
import "package:ciyue/main.dart";
import "package:ciyue/settings.dart";
import "package:ciyue/widget/text_buttons.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

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

class WordBookScreen extends StatelessWidget {
  const WordBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: WordViewWithTagsClips(),
    );
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

  const WordView({
    super.key,
    required this.allWords,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: allWords,
        builder:
            (BuildContext context, AsyncSnapshot<List<WordbookData>> snapshot) {
          final list = <Widget>[];
          if (snapshot.hasData) {
            for (final data in snapshot.data!) {
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
            return Expanded(
                child:
                    Center(child: Text(AppLocalizations.of(context)!.empty)));
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

class _WordViewWithTagsClipsState extends State<WordViewWithTagsClips> {
  late Future<List<WordbookData>> allWords;
  late Future<List<WordbookTag>> tags;

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

                return Wrap(spacing: 8.0, children: choiceChips);
              }

              return Wrap();
            }),
        WordView(allWords: allWords),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    allWords =
        wordbookDao.getAllWordsWithTag(skipTagged: settings.skipTaggedWord);
    tags = wordbookTagsDao.getAllTags();

    _refreshTagsAndWords = refresh;
  }

  void refresh() {
    setState(() {
      allWords =
          wordbookDao.getAllWordsWithTag(skipTagged: settings.skipTaggedWord);
      tags = wordbookTagsDao.getAllTags();
    });
  }
}

import "package:ciyue/database/app.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/widget/text_buttons.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

VoidCallback? _refreshTagsAndWords;

class WordBookScreen extends StatelessWidget {
  const WordBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    late final PreferredSizeWidget? appBar;
    if (!dictManager.isEmpty) {
      appBar = AppBar(
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
          )
        ],
      );
    } else {
      appBar = null;
    }

    return Scaffold(
      appBar: appBar,
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

                  if (_refreshTagsAndWords != null) _refreshTagsAndWords!();

                  if (context.mounted) context.pop();
                },
              )
            ],
          );
        });
  }

  Future<void> buildTagsList(
      BuildContext context, List<WordbookTag> tags) async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          final tagListTile = <Widget>[];
          for (final tag in tags) {
            tagListTile.add(ListTile(
              title: Text(tag.tag),
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

          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.tagList),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...tagListTile,
              ],
            ),
            actions: [
              TextCloseButton(),
              TextButton(
                child: Text(AppLocalizations.of(context)!.add),
                onPressed: () async {
                  context.pop();
                  await buildAddTag(context);
                },
              ),
            ],
          );
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

class _WordViewWithTagsClipsState extends State<WordViewWithTagsClips> {
  late Future<List<WordbookData>> allWords;
  late Future<List<WordbookTag>> tags;

  int? selectedTag;

  @override
  Widget build(BuildContext context) {
    if (dictManager.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.empty));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder(
            future: tags,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final choiceChips = <Widget>[];

                for (final tag in snapshot.data!) {
                  choiceChips.add(ChoiceChip(
                    label: Text(tag.tag),
                    selected: selectedTag == tag.id,
                    onSelected: (selected) {
                      setState(() {
                        selectedTag = selected ? tag.id : null;
                        allWords =
                            wordbookDao.getAllWordsWithTag(tag: selectedTag);
                      });
                    },
                  ));
                }

                return Wrap(children: choiceChips);
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

    if (!dictManager.isEmpty) {
      allWords = wordbookDao.getAllWordsWithTag();
      tags = wordbookTagsDao.getAllTags();
    }

    _refreshTagsAndWords = refresh;
  }

  void refresh() {
    setState(() {
      allWords = wordbookDao.getAllWordsWithTag();
      tags = wordbookTagsDao.getAllTags();
    });
  }
}

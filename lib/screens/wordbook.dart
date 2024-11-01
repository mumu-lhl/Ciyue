import "package:ciyue/database/dictionary.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/widget/text_buttons.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

class WordBookScreen extends StatefulWidget {
  const WordBookScreen({super.key});

  @override
  State<WordBookScreen> createState() => _WordBookScreenState();
}

class WordListView extends StatelessWidget {
  const WordListView({super.key});

  @override
  Widget build(BuildContext context) {
    if (dict.db == null) {
      return Center(child: Text(AppLocalizations.of(context)!.empty));
    }

    final allWords = dict.db!.getAllWords();

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
                  final offset = await dict.db!.getOffset(data.word);
                  String content = await dict.reader!.readOne(
                      offset.blockOffset,
                      offset.startOffset,
                      offset.endOffset,
                      offset.compressedSize);

                  if (context.mounted) {
                    context.push("/word",
                        extra: {"content": content, "word": data.word});
                  }
                },
              ));
            }
          }

          if (list.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.empty));
          } else {
            return ListView(children: list);
          }
        });
  }
}

class _WordBookScreenState extends State<WordBookScreen> {
  @override
  Widget build(BuildContext context) {
    late final PreferredSizeWidget? appBar;
    if (dict.db != null) {
      appBar = AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.bookmark),
            onPressed: () async {
              final tags = await dict.db!.getAllTags();

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
      body: WordListView(),
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
                  await dict.db!.addTag(textController.text);
                  await dict.checkTagExist();

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
                  await dict.db!.removeTag(tag.id);
                  await dict.checkTagExist();

                  if (context.mounted) context.pop();
                },
              ),
            ));
          }

          return SimpleDialog(
              title: Text(AppLocalizations.of(context)!.tagList),
              children: [
                ...tagListTile,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextCloseButton(),
                    TextButton(
                      child: Text(AppLocalizations.of(context)!.add),
                      onPressed: () async {
                        context.pop();
                        await buildAddTag(context);
                      },
                    ),
                  ],
                ),
              ]);
        });
  }
}

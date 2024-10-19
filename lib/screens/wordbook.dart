import "package:ciyue/database/dictionary.dart";
import "package:ciyue/dictionary.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

class WordBookScreen extends StatelessWidget {
  const WordBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (dict.db == null) {
      return ListView();
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

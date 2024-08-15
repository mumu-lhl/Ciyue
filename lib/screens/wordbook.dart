import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../database.dart";
import "../main.dart";

class WordBookScreen extends StatelessWidget {
  const WordBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (dictionary == null) {
      return ListView();
    }

    final allWords = dictionary!.getAllWords();

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
                  final offset = await dictionary!.getOffset(data.word);
                  String content = await dictReader!.readOne(
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

          return ListView(children: list);
        });
  }
}

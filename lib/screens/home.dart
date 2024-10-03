import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

import "../database/dictionary.dart";
import "../main.dart";

class HomeScreen extends StatelessWidget {
  final String searchWord;
  final List<DictionaryData> searchResult;

  const HomeScreen(
      {super.key, required this.searchWord, required this.searchResult});

  @override
  Widget build(BuildContext context) {
    Widget body;

    final locale = AppLocalizations.of(context);

    if (dict.path == null) {
      body = Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(locale!.addDictionary),
          ElevatedButton(
            child: Text(locale.recommendedDictionaries),
            onPressed: () async {
              await launchUrl(Uri.parse(
                  "https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries"));
            },
          )
        ],
      ));
    } else {
      if (searchWord == "") {
        body = Center(child: Text(locale!.startToSearch));
      } else {
        body = Center(child: SearchResult(searchResult: searchResult));
      }
    }

    return body;
  }
}

class SearchResult extends StatelessWidget {
  final List<DictionaryData> searchResult;

  const SearchResult({super.key, required this.searchResult});

  @override
  Widget build(BuildContext context) {
    final resultWidgets = <Widget>[];

    for (var word in searchResult) {
      resultWidgets.add(ListTile(
          title: Text(word.key),
          trailing: IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () async {
              await flutterTts.speak(word.key);
            },
          ),
          onTap: () async {
            String content = await dict.reader!.readOne(word.blockOffset,
                word.startOffset, word.endOffset, word.compressedSize);

            if (content.startsWith("@@@LINK=")) {
              // 8: remove @@@LINK=
              // content.length - 3: remove \r\n\x00
              word = await dict.db!.getOffset(
                  content.substring(8, content.length - 3).trimRight());
              content = await dict.reader!.readOne(word.blockOffset,
                  word.startOffset, word.endOffset, word.compressedSize);
            }

            if (context.mounted) {
              context
                  .push("/word", extra: {"content": content, "word": word.key});
            }
          }));
    }

    return ListView(
      children: resultWidgets,
    );
  }
}

import "package:ciyue/database/dictionary.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

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

    for (final word in searchResult) {
      resultWidgets.add(ListTile(
          title: Text(word.key),
          trailing: IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () async {
              await flutterTts.speak(word.key);
            },
          ),
          onTap: () async {
            context.push("/word", extra: {"word": word.key});
          }));
    }

    if (searchResult.isEmpty) {
      return Center(
          child: Text(AppLocalizations.of(context)!.noResult,
              style: Theme.of(context).textTheme.titleLarge));
    } else {
      return ListView(
        children: resultWidgets,
      );
    }
  }
}

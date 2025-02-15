import "package:ciyue/database/app.dart";
import "package:ciyue/database/dictionary.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/pages/main/main.dart";
import "package:ciyue/settings.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

class HomeScreen extends StatelessWidget {
  final String searchWord;

  const HomeScreen({super.key, required this.searchWord});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    if (dictManager.isEmpty) {
      return Center(
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
        final future = historyDao.getAllHistory();
        return buildHistory(context, future);
      } else {
        final searchers = <Future<List<DictionaryData>>>[];
        for (final dict in dictManager.dicts.values) {
          searchers.add(dict.db.searchWord(searchWord));
        }
        final future = Future.wait(searchers);

        return buildSearchResult(future);
      }
    }
  }

  FutureBuilder<List<HistoryData>> buildHistory(
      BuildContext context, Future<List<HistoryData>> future) {
    final locale = AppLocalizations.of(context);

    return FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final history = snapshot.data as List<HistoryData>;
            if (history.isEmpty) {
              return Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [Text(locale!.startToSearch)],
              ));
            }
            return ListView(
              children: [
                for (final item in history)
                  Dismissible(
                    key: ValueKey(item.id),
                    onDismissed: (direction) async {
                      if (direction == DismissDirection.endToStart) {
                        await buildRemoveHistoryConfirmDialog(context, item);
                      }
                    },
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.endToStart) {
                        final result = await buildRemoveHistoryConfirmDialog(context, item);
                        return result;
                      } else {
                        if (await wordbookDao.wordExist(item.word)) {
                          await wordbookDao.removeWord(item.word);
                        } else {
                          await wordbookDao.addWord(item.word);
                        }
                        return false;
                      }
                    },
                    background: Container(
                        color: Colors.blue, child: const Icon(Icons.book)),
                    secondaryBackground: Container(
                        color: Colors.red, child: const Icon(Icons.delete)),
                    child: ListTile(
                      title: Text(item.word),
                      onTap: () {
                        context.push("/word", extra: {"word": item.word});
                      },
                      onLongPress: () async {
                        await buildRemoveHistoryConfirmDialog(context, item);
                      },
                    ),
                  )
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        });
  }

  Future<bool> buildRemoveHistoryConfirmDialog(
      BuildContext context, HistoryData item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.removeOneHistory),
        content: Text(AppLocalizations.of(context)!
            .removeOneHistoryConfirm
            .replaceFirst("%s", item.word)),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(AppLocalizations.of(context)!.close),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(AppLocalizations.of(context)!.remove),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await historyDao.removeHistory(item.word);
    }
    return confirmed ?? false;
  }

  FutureBuilder<List<List<DictionaryData>>> buildSearchResult(
      Future<List<List<DictionaryData>>> future) {
    return FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final searchResult = [for (final i in snapshot.data!) ...i];
            searchResult.sort((a, b) => a.key.compareTo(b.key));

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
                    await historyDao.addHistory(word.key);
                    if (settings.autoRemoveSearchWord) {
                      clearSearchWord();
                    }
                  }));
            }

            if (searchResult.isEmpty) {
              return Center(
                  child: Text(AppLocalizations.of(context)!.noResult,
                      style: Theme.of(context).textTheme.titleLarge));
            } else {
              return ListView(children: resultWidgets);
            }
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        });
  }
}

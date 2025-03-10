import "package:ciyue/database/app.dart";
import "package:ciyue/database/dictionary.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/pages/main/main.dart";
import "package:ciyue/settings.dart";
import "package:ciyue/widget/tags_list.dart";
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
          SizedBox(height: 16),
          ElevatedButton(
            child: Text(locale.recommendedDictionaries),
            onPressed: () async {
              await launchUrl(Uri.parse(
                  "https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries"));
            },
          ),
          SizedBox(height: 8),
          ElevatedButton(
            child: const Text("FreeMDict Cloud"),
            onPressed: () async {
              await launchUrl(Uri.parse(
                  "https://cloud.freemdict.com/index.php/s/pgKcDcbSDTCzXCs"));
            },
          ),
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
                        final result = await buildRemoveHistoryConfirmDialog(
                            context, item);
                        return result;
                      } else {
                        if (wordbookTagsDao.tagExist) {
                          final tagsOfWord =
                                  await wordbookDao.tagsOfWord(item.word),
                              tags = await wordbookTagsDao.getAllTags();
                          final toAdd = <int>[], toDel = <int>[];

                          if (!context.mounted) return false;

                          await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(AppLocalizations.of(context)!.tags),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TagsList(
                                      tags: tags,
                                      tagsOfWord: tagsOfWord,
                                      toAdd: toAdd,
                                      toDel: toDel,
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    child: Text(
                                        AppLocalizations.of(context)!.close),
                                    onPressed: () {
                                      context.pop(false);
                                    },
                                  ),
                                  TextButton(
                                    child: Text(
                                        AppLocalizations.of(context)!.remove),
                                    onPressed: () async {
                                      await wordbookDao
                                          .removeWordWithAllTags(item.word);
                                      if (context.mounted) context.pop(true);
                                    },
                                  ),
                                  TextButton(
                                    child: Text(
                                        AppLocalizations.of(context)!.confirm),
                                    onPressed: () async {
                                      if (!await wordbookDao
                                          .wordExist(item.word)) {
                                        await wordbookDao.addWord(item.word);
                                      }

                                      for (final tag in toAdd) {
                                        await wordbookDao.addWord(item.word,
                                            tag: tag);
                                      }

                                      for (final tag in toDel) {
                                        await wordbookDao.removeWord(item.word,
                                            tag: tag);
                                      }

                                      if (context.mounted) context.pop(true);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                          return false;
                        } else {
                          if (await wordbookDao.wordExist(item.word)) {
                            await wordbookDao.removeWord(item.word);
                          } else {
                            await wordbookDao.addWord(item.word);
                          }
                          return false;
                        }
                      }
                    },
                    background: Container(
                        color: Colors.blue,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16.0),
                        child: const Icon(Icons.label)),
                    secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16.0),
                        child: const Icon(Icons.delete)),
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
            searchResult.removeWhere((element) =>
                searchResult.indexOf(element) !=
                searchResult.lastIndexWhere((e) => e.key == element.key));

            final resultWidgets = <Widget>[];

            for (final word in searchResult) {
              resultWidgets.add(ListTile(
                  trailing: Icon(Icons.arrow_forward),
                  title: Text(word.key),
                  leading: IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () async {
                      await flutterTts.speak(word.key);
                    },
                  ),
                  onTap: () async {
                    context.push("/word", extra: {"word": word.key});
                    await historyDao.addHistory(word.key);
                    if (settings.autoRemoveSearchWord) {
                      MainPage.clearSearchWord();
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

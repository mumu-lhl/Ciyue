import "package:ciyue/database/app.dart";
import "package:ciyue/database/dictionary.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/widget/tags_list.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

final _textFieldController = TextEditingController();

class HomeModel extends ChangeNotifier {
  void update() {
    notifyListeners();
  }
}

class HomePage {
  static VoidCallback? _enableAutofocusOnce;

  static bool callEnableAutofocusOnce = false;

  static VoidCallback get enableAutofocusOnce => _enableAutofocusOnce!;
  static set enableAutofocusOnce(VoidCallback callback) =>
      _enableAutofocusOnce = callback;

  static void setSearchWord(String word) {
    _textFieldController.text = word;
  }
}

class HistoryList extends StatefulWidget {
  const HistoryList({super.key});

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    final future = historyDao.getAllHistory();

    return FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final history = snapshot.data as List<HistoryData>;
            if (history.isEmpty) {
              return Center(child: Text(locale!.startToSearch));
            }
            return ListView(
              children: [
                for (final item in history)
                  Dismissible(
                    key: ValueKey(item.id),
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
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class MoreOptionsDialog extends StatefulWidget {
  const MoreOptionsDialog({super.key});

  @override
  State<MoreOptionsDialog> createState() => _MoreOptionsDialogState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _autofocus = false;

  @override
  Widget build(BuildContext context) {
    context.watch<HomeModel>();

    return Scaffold(
      appBar: buildAppBar(context),
      body: Column(
        children: [
          Expanded(child: buildBody(context)),
          if (!settings.searchBarInAppBar)
            Padding(
                padding: const EdgeInsets.only(
                    left: 20, right: 20, bottom: 10, top: 10),
                child: buildSearchBar(context)),
        ],
      ),
      drawer: buildDrawer(),
    );
  }

  AppBar? buildAppBar(BuildContext context) {
    if (!dictManager.isEmpty || settings.aiExplainWord) {
      final searchBar =
          settings.searchBarInAppBar ? buildSearchBar(context) : null;
      return AppBar(
        title: searchBar,
        automaticallyImplyLeading: settings.showSidebarIcon,
        actions: [
          if (settings.showMoreOptionsButton) buildMoreButton(context),
        ],
      );
    }
    return null;
  }

  Widget buildBody(BuildContext context) {
    final locale = AppLocalizations.of(context);

    if (dictManager.isEmpty && !settings.aiExplainWord) {
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
        ),
      );
    } else {
      if (_textFieldController.text.isEmpty) {
        return HistoryList();
      } else {
        final searchers = <Future<List<DictionaryData>>>[];
        for (final dict in dictManager.dicts.values) {
          searchers.add(dict.db.searchWord(_textFieldController.text));
        }
        final future = Future.wait(searchers);

        return buildSearchResult(future);
      }
    }
  }

  Drawer buildDrawer() {
    return Drawer(
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            DrawerHeader(
              child: Text(
                AppLocalizations.of(context)!.dictionaryGroups,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            for (final group in dictManager.groups)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: group.id == dictManager.groupId
                      ? const Icon(Icons.radio_button_checked, size: 20)
                      : const Icon(Icons.radio_button_unchecked, size: 20),
                  title: Text(group.name == "Default"
                      ? AppLocalizations.of(context)!.default_
                      : group.name),
                  onTap: ()  {
                    context.pop();
                    dictManager.setCurrentGroup(group.id);
                    context.read<HomeModel>().update();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }


  Padding buildMoreButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () async {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return const MoreOptionsDialog();
            },
          );
        },
      ),
    );
  }

  ListTile buildOneResult(String word, BuildContext context) {
    return ListTile(
        trailing: Icon(Icons.arrow_circle_right_outlined),
        title: Text(word),
        leading: IconButton(
          icon: const Icon(Icons.volume_up),
          onPressed: () async {
            await flutterTts.speak(word);
          },
        ),
        onTap: () async {
          context.push("/word", extra: {"word": word});
          await historyDao.addHistory(word);
          if (settings.autoRemoveSearchWord) {
            _textFieldController.clear();
          }
        });
  }

  IconButton buildRemoveButton() {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () {
        setState(() {
          _textFieldController.clear();
        });
      },
    );
  }

  Widget buildSearchBar(BuildContext context) {
    final autofocus = _autofocus;
    _autofocus = false;

    return SafeArea(
      child: Center(
        child: SearchBar(
          autoFocus: autofocus,
          onTapOutside: (pointerDownEvent) {
            FocusScope.of(context).unfocus();
          },
          hintText: AppLocalizations.of(context)!.search,
          controller: _textFieldController,
          elevation: WidgetStateProperty.all(1),
          constraints:
              const BoxConstraints(maxHeight: 42, minHeight: 42, maxWidth: 500),
          leading: const Icon(Icons.search),
          onChanged: (value) {
            setState(() {});
          },
          trailing: [
            if (_textFieldController.text.isNotEmpty) buildRemoveButton()
          ],
        ),
      ),
    );
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

            if (settings.aiExplainWord &&
                (searchResult.isEmpty ||
                    searchResult[0].key != _textFieldController.text)) {
              resultWidgets
                  .add(buildOneResult(_textFieldController.text, context));
            }
            for (final word in searchResult) {
              resultWidgets.add(buildOneResult(word.key, context));
            }

            if (resultWidgets.isEmpty) {
              return Center(
                  child: Text(AppLocalizations.of(context)!.noResult,
                      style: Theme.of(context).textTheme.titleLarge));
            } else {
              return ListView(children: resultWidgets);
            }
          } else {
            return Center(child: CircularProgressIndicator());
          }
        });
  }

  @override
  void initState() {
    super.initState();

    HomePage.enableAutofocusOnce = () {
      setState(() {
        _autofocus = true;
      });
    };
    if (HomePage.callEnableAutofocusOnce) {
      HomePage.enableAutofocusOnce();
      HomePage.callEnableAutofocusOnce = false;
    }
  }
}

class _MoreOptionsDialogState extends State<MoreOptionsDialog> {
  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(AppLocalizations.of(context)!.more),
      children: [
        SimpleDialogOption(
          child: CheckboxListTile(
            value: settings.autoRemoveSearchWord,
            onChanged: (value) async {
              if (value != null) {
                settings.autoRemoveSearchWord = value;
                await prefs.setBool("autoRemoveSearchWord", value);
                setState(() {});
              }
            },
            title: Text(AppLocalizations.of(context)!.autoRemoveSearchWord),
          ),
        ),
      ],
    );
  }
}

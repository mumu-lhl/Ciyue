import "package:ciyue/database/app.dart";
import "package:ciyue/database/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/services/dictionary.dart";
import "package:ciyue/services/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/widget/tags_list.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

class AddHistoryToWordbookDialog extends StatelessWidget {
  final List<WordbookTag> tags;

  final List<int> tagsOfWord;
  final List<int> toAdd;
  final List<int> toDel;
  final HistoryData item;
  const AddHistoryToWordbookDialog({
    super.key,
    required this.tags,
    required this.tagsOfWord,
    required this.toAdd,
    required this.toDel,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
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
          child: Text(AppLocalizations.of(context)!.close),
          onPressed: () {
            context.pop(false);
          },
        ),
        TextButton(
          child: Text(AppLocalizations.of(context)!.remove),
          onPressed: () async {
            await wordbookDao.removeWordWithAllTags(item.word);
            if (context.mounted) context.pop(true);
          },
        ),
        TextButton(
          child: Text(AppLocalizations.of(context)!.confirm),
          onPressed: () async {
            if (!await wordbookDao.wordExist(item.word)) {
              await wordbookDao.addWord(item.word);
            }

            for (final tag in toAdd) {
              await wordbookDao.addWord(item.word, tag: tag);
            }

            for (final tag in toDel) {
              await wordbookDao.removeWord(item.word, tag: tag);
            }

            if (context.mounted) context.pop(true);
          },
        ),
      ],
    );
  }
}

class HistoryList extends StatelessWidget {
  const HistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<HistoryModel>();

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
                        return await buildRemoveHistoryConfirmDialog(
                            context, item, model);
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
                              return AddHistoryToWordbookDialog(
                                  tags: tags,
                                  tagsOfWord: tagsOfWord,
                                  toAdd: toAdd,
                                  toDel: toDel,
                                  item: item);
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
                        color: Theme.of(context).colorScheme.primary,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Icon(Icons.book_outlined,
                            color: Theme.of(context).colorScheme.onPrimary)),
                    secondaryBackground: Container(
                        color: Theme.of(context).colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Icon(Icons.delete_outline,
                            color: Theme.of(context).colorScheme.onError)),
                    child: ListTile(
                      title: Text(item.word),
                      onTap: () {
                        context.push("/word", extra: {"word": item.word});
                      },
                      onLongPress: () async {
                        await buildRemoveHistoryConfirmDialog(
                            context, item, model);
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
      BuildContext context, HistoryData item, HistoryModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => RemoveHistoryConfirmDialog(item: item),
    );
    if (confirmed == true) {
      model.removeHistory(item.word);
    }
    return confirmed ?? false;
  }
}

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({
    super.key,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final searchBar = settings.searchBarInAppBar ? HomeSearchBar() : null;
    return AppBar(
      title: searchBar,
      automaticallyImplyLeading: settings.showSidebarIcon,
      actions: [
        if (settings.showMoreOptionsButton) MoreButton(),
      ],
    );
  }
}

class HomeBody extends StatelessWidget {
  const HomeBody({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    context.select<DictManagerModel, bool>((value) => value.isEmpty);
    context.select<HomeModel, String>((value) => value.searchWord);

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
      final searchWord = context.read<HomeModel>().searchWord;
      if (searchWord.isEmpty) {
        return HistoryList();
      } else {
        return SearchResults();
      }
    }
  }
}

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final groupId =
        context.select<DictManagerModel, int>((value) => value.groupId);

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
                  leading: group.id == groupId
                      ? const Icon(Icons.radio_button_checked, size: 20)
                      : const Icon(Icons.radio_button_unchecked, size: 20),
                  title: Text(group.name == "Default"
                      ? AppLocalizations.of(context)!.default_
                      : group.name),
                  onTap: () async {
                    context.pop();
                    await context
                        .read<DictManagerModel>()
                        .setCurrentGroup(group.id);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.select<HomeModel, int>((model) => model.state);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Selector<DictManagerModel, bool>(
          selector: (_, model) => model.isEmpty,
          builder: (BuildContext context, value, Widget? child) {
            return (!dictManager.isEmpty || settings.aiExplainWord)
                ? HomeAppBar()
                : const SizedBox.shrink();
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(child: HomeBody()),
          if (!settings.searchBarInAppBar)
            Selector<DictManagerModel, bool>(
              selector: (_, model) => model.isEmpty,
              builder: (_, isEmpty, ___) => isEmpty ? SizedBox.shrink() : Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, bottom: 10, top: 10),
                  child: HomeSearchBar()),
            ),
        ],
      ),
      drawer: HomeDrawer(),
    );
  }
}

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textFieldController =
        context.select<HomeModel, TextEditingController>(
            (model) => model.textFieldController);
    final autofocus =
        context.select<HomeModel, bool>((model) => model.autofocus);

    context.select<HomeModel, String>((model) => model.searchWord);

    final model = context.read<HomeModel>();
    if (autofocus) {
      model.autofocus = false;
    }

    return SafeArea(
      child: Center(
        child: SearchBar(
          autoFocus: autofocus,
          onTapOutside: (pointerDownEvent) {
            FocusScope.of(context).unfocus();
          },
          hintText: AppLocalizations.of(context)!.search,
          controller: textFieldController,
          elevation: WidgetStateProperty.all(1),
          constraints:
              const BoxConstraints(maxHeight: 42, minHeight: 42, maxWidth: 500),
          leading: const Icon(Icons.search),
          trailing: [
            if (textFieldController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => model.clearSearchWord(),
              )
          ],
          onChanged: (value) => model.searchWord = value,
        ),
      ),
    );
  }
}

class MoreButton extends StatelessWidget {
  const MoreButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
}

class MoreOptionsDialog extends StatefulWidget {
  const MoreOptionsDialog({super.key});

  @override
  State<MoreOptionsDialog> createState() => _MoreOptionsDialogState();
}

class OneSearchResult extends StatelessWidget {
  final String word;

  const OneSearchResult({
    super.key,
    required this.word,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
        trailing: Icon(Icons.arrow_forward),
        title: Text(word),
        leading: IconButton(
          icon: const Icon(Icons.volume_up_outlined),
          onPressed: () async {
            await flutterTts.speak(word);
          },
        ),
        onTap: () async {
          context.push("/word", extra: {"word": word});
          await historyDao.addHistory(word);
          if (settings.autoRemoveSearchWord && context.mounted) {
            context.read<HomeModel>().clearSearchWord();
          }
        });
  }
}

class RemoveHistoryConfirmDialog extends StatelessWidget {
  final HistoryData item;

  const RemoveHistoryConfirmDialog({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
    );
  }
}

class Searcher {
  final String text;

  Searcher(this.text);

  Future<List<DictionaryData>> getSearchResult() async {
    final searchers = <Future<List<DictionaryData>>>[];
    for (final dict in dictManager.dicts.values) {
      searchers.add(dict.db.searchWord(text));
    }
    final searchResult = [for (final i in await Future.wait(searchers)) ...i];
    searchResult.sort((a, b) => a.key.compareTo(b.key));
    searchResult.removeWhere((element) =>
        searchResult.indexOf(element) !=
        searchResult.lastIndexWhere((e) => e.key == element.key));
    return searchResult;
  }
}

class SearchResults extends StatelessWidget {
  const SearchResults({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.select<HomeModel, String>((model) => model.searchWord);

    return FutureBuilder(
        future: Searcher(text).getSearchResult(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final searchResult = snapshot.data as List<DictionaryData>;
            final resultWidgets = <Widget>[];

            if (settings.aiExplainWord &&
                (searchResult.isEmpty || searchResult[0].key != text)) {
              resultWidgets.add(OneSearchResult(word: text));
            }
            for (final word in searchResult) {
              resultWidgets.add(OneSearchResult(word: word.key));
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
                if (context.mounted) context.read<HomeModel>().update();
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

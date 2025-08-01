import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:ciyue/ui/core/tags_list.dart";
import "package:ciyue/viewModels/wordbook.dart";
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
            if (context.mounted) {
              context.pop(true);
              context.read<WordbookModel>().updateWordList();
            }
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

            if (context.mounted) {
              context.pop(true);
              context.read<WordbookModel>().updateWordList();
            }
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
    final history = model.history;

    final locale = AppLocalizations.of(context);

    if (history.isEmpty) {
      return Expanded(child: Center(child: Text(locale!.startToSearch)));
    }

    return Expanded(
      child: ListView(
        children: [
          for (final item in history)
            Dismissible(
              key: ValueKey(item.id),
              confirmDismiss: (direction) async {
                if (model.isSelecting) return false;

                if (direction == DismissDirection.endToStart) {
                  final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(locale!.confirmDelete),
                          content: Text(locale.confirmDeleteMessage(item.word)),
                          actions: [
                            TextButton(
                              onPressed: () => context.pop(false),
                              child: Text(locale.close),
                            ),
                            TextButton(
                              onPressed: () => context.pop(true),
                              child: Text(locale.remove),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (confirm) {
                    model.deleteHistory(item.id);
                  }
                  return confirm;
                }

                if (wordbookTagsDao.tagExist) {
                  final tagsOfWord = await wordbookDao.tagsOfWord(item.word),
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
                }

                if (await wordbookDao.wordExist(item.word)) {
                  await wordbookDao.removeWord(item.word);
                } else {
                  await wordbookDao.addWord(item.word);
                }
                if (context.mounted) {
                  context.read<WordbookModel>().updateWordList();
                }

                return false;
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
                leading: model.isSelecting
                    ? Checkbox(
                        value: model.selectedIds.contains(item.id),
                        onChanged: (value) {
                          model.toggleSelection(item.id);
                        },
                      )
                    : null,
                title: Text(item.word),
                onTap: () {
                  if (model.isSelecting) {
                    model.toggleSelection(item.id);
                  } else {
                    context.push("/word", extra: {"word": item.word});
                  }
                },
                onLongPress: () {
                  model.toggleSelection(item.id);
                },
              ),
            )
        ],
      ),
    );
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
    final model = context.watch<HistoryModel>();

    if (model.isSelecting) {
      return AppBar(
        title: Text(
            AppLocalizations.of(context)!.nSelected(model.selectedIds.length)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            model.clearSelection();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: () => model.selectAll(),
          ),
          IconButton(
            icon: const Icon(Icons.book_outlined),
            onPressed: () async {
              await model.addSelectedToWordbook();
              if (context.mounted) {
                context.read<WordbookModel>().updateWordList();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => model.deleteSelected(),
          ),
        ],
      );
    } else {
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
}

class ActionButtons extends StatelessWidget {
  const ActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              OneActionButton(
                  title: AppLocalizations.of(context)!.writingCheck,
                  path: "/writing_check",
                  icon: Icons.spellcheck_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class OneActionButton extends StatelessWidget {
  final String title;
  final String path;
  final IconData icon;

  const OneActionButton({
    super.key,
    required this.title,
    required this.path,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: AppLocalizations.of(context)!.writingCheck,
      icon: Icon(Icons.spellcheck_outlined,
          color: Theme.of(context).colorScheme.primary),
      onPressed: () {
        context.push("/writing_check");
      },
    );
  }
}

class HomeBody extends StatelessWidget {
  const HomeBody({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    context.select<HomeModel, int>((value) => value.state);
    context.select<DictManagerModel, bool>((value) => value.isEmpty);

    final locale = AppLocalizations.of(context);

    if (dictManager.isEmpty && !settings.aiExplainWord) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(locale!.addDictionary),
            const SizedBox(height: 16),
            ElevatedButton(
              child: Text(locale.recommendedDictionaries),
              onPressed: () async {
                await launchUrl(Uri.parse(
                    "https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries"));
              },
            ),
            const SizedBox(height: 8),
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ActionButtons(),
          const HistoryLabel(),
          const HistoryList(),
        ],
      );
    }
  }
}

class HistoryLabel extends StatelessWidget {
  const HistoryLabel({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
      child: Text(
        AppLocalizations.of(context)!.history,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color:
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7)),
      ),
    );
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

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final searchWord =
        context.select<HomeModel, String>((model) => model.searchWord);
    final model = context.read<HomeModel>();

    return FocusScope(
      child: WordSearchBarWithSuggestions(
        word: searchWord,
        controller: model.searchController,
        focusNode: model.searchBarFocusNode,
        isHome: true,
        autoFocus: true,
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.select<HomeModel, int>((value) => value.state);
    context.select<DictManagerModel, bool>((value) => value.isEmpty);
    final historyModel = context.watch<HistoryModel>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: (!dictManager.isEmpty || settings.aiExplainWord)
            ? const HomeAppBar()
            : const SizedBox.shrink(),
      ),
      body: Column(
        children: [
          const Expanded(child: HomeBody()),
          if (!settings.searchBarInAppBar)
            Selector<DictManagerModel, bool>(
                selector: (_, model) => model.isEmpty,
                builder: (_, isEmpty, __) => isEmpty
                    ? const SizedBox.shrink()
                    : const Padding(
                        padding: EdgeInsets.only(
                            left: 20, right: 20, bottom: 10, top: 10),
                        child: HomeSearchBar(),
                      )),
        ],
      ),
      drawer: historyModel.isSelecting ? null : const HomeDrawer(),
      // floatingActionButton: FloatingActionButton(
      //   heroTag: "chatButton",
      //   onPressed: () {
      //     context.push("/chat");
      //   },
      //   child: const Icon(Icons.chat),
      // ),
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

class Searcher {
  final String text;

  Searcher(this.text);

  Future<List<String>> getSearchResult() async {
    final searchers = <Future<List<String>>>[];
    for (final dict in dictManager.dicts.values) {
      searchers.add(dict.db.searchWord(text));
    }

    final searchResult = [for (final i in await Future.wait(searchers)) ...i];
    searchResult.sort((a, b) => a.compareTo(b));

    final seen = <String>{};
    final deduped = <String>[];
    for (final s in searchResult) {
      if (seen.add(s)) {
        deduped.add(s);
      }
    }

    return deduped;
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

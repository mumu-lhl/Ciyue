import "package:ciyue/core/app_globals.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

import "dialogs.dart";

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
                  if (!context.mounted) return null;

                  await context.read<WordbookModel>().delete(item.word);
                } else {
                  if (!context.mounted) return null;

                  await context.read<WordbookModel>().add(item.word);
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
                    context.push("/word/${Uri.encodeComponent(item.word)}");
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

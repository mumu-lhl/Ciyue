import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/gestures.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "dialogs.dart";

class HistoryList extends ConsumerWidget {
  final ValueChanged<String>? onWordSelected;
  final ValueChanged<String>? onWordTertiarySelected;
  final String? selectedWord;

  const HistoryList({
    super.key,
    this.onWordSelected,
    this.onWordTertiarySelected,
    this.selectedWord,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(historyModelProvider);
    final history = model.history;

    final locale = AppLocalizations.of(context);

    if (history.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                locale!.startToSearch,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                locale.empty,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: history.length,
        separatorBuilder: (context, index) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final item = history[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Dismissible(
              key: ValueKey(item.id),
              confirmDismiss: (direction) async {
                if (model.isSelecting) return false;

                if (direction == DismissDirection.endToStart) {
                  final confirm =
                      await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(locale!.confirmDelete),
                          content: Text(locale.confirmDeleteMessage(item.word)),
                          actions: [
                            TextButton(
                              onPressed: () => context.pop(false),
                              child: Text(locale.close),
                            ),
                            FilledButton.tonal(
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
                        item: item,
                      );
                    },
                  );
                  return false;
                }

                if (await wordbookDao.wordExist(item.word)) {
                  if (!context.mounted) return null;

                  await ref.read(wordbookModelProvider).delete(item.word);
                } else {
                  if (!context.mounted) return null;

                  await ref.read(wordbookModelProvider).add(item.word);
                }
                if (context.mounted) {
                  ref.read(wordbookModelProvider).updateWordList();
                }

                return false;
              },
              background: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20.0),
                child: Icon(
                  Icons.bookmark_add_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              secondaryBackground: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20.0),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              child: Listener(
                onPointerDown: (event) {
                  if (event.buttons == kTertiaryButton && !model.isSelecting) {
                    if (onWordTertiarySelected != null) {
                      onWordTertiarySelected!(item.word);
                    } else if (onWordSelected != null) {
                      onWordSelected!(item.word);
                    }
                  }
                },
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selected: !model.isSelecting && selectedWord == item.word,
                  selectedTileColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.45),
                  leading: model.isSelecting
                      ? Checkbox(
                          value: model.selectedIds.contains(item.id),
                          onChanged: (value) {
                            model.toggleSelection(item.id);
                          },
                        )
                      : Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                  title: Text(
                    item.word,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () {
                    if (model.isSelecting) {
                      model.toggleSelection(item.id);
                    } else if (onWordSelected != null) {
                      onWordSelected!(item.word);
                    } else {
                      context.push("/word/${Uri.encodeComponent(item.word)}");
                    }
                  },
                  onLongPress: () {
                    model.toggleSelection(item.id);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class HistoryLabel extends StatelessWidget {
  const HistoryLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context)!.history,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

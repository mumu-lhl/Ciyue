import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/dictionary_files.dart";
import "package:ciyue/repositories/hunspell.dart";
import "package:ciyue/repositories/stardict.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/loading_dialog.dart";
import "package:ciyue/utils.dart";
import "package:file_selector/file_selector.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:path/path.dart";
import "package:url_launcher/url_launcher.dart";

Future<void> addGroup(String value, BuildContext context) async {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return;

  final existingGroups = await dictGroupDao.getAllGroups();
  final alreadyExists = existingGroups.any(
    (g) => g.name.toLowerCase() == trimmed.toLowerCase(),
  );

  if (alreadyExists) {
    if (context.mounted) {
      ToastService.show(
        AppLocalizations.of(context)!.groupNameAlreadyExists,
        context,
        type: ToastType.info,
      );
    }
    return;
  }

  try {
    await dictGroupDao.addGroup(trimmed, []);
  } catch (e, stackTrace) {
    talker.error("Failed to add group \"$trimmed\": $e", e, stackTrace);
    if (context.mounted) {
      // Only a UNIQUE violation means the name is taken. Anything else is a
      // storage failure and used to be reported as "name already exists",
      // which sent the user looking for a group that was never there.
      ToastService.show(
        e.toString().contains("UNIQUE constraint failed")
            ? AppLocalizations.of(context)!.groupNameAlreadyExists
            : AppLocalizations.of(context)!.groupAddFailed,
        context,
        type: ToastType.error,
      );
    }
    return;
  }

  // The row is stored from here on. Refreshing the list and closing the dialog
  // must not be able to turn a successful insert into an error message, and
  // the provider container is read from the dialog's own context: `ref` here
  // belonged to the group dialog, which is already popped by the time the
  // user confirms the name.
  if (!context.mounted) return;
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    await container.read(dictManagerModelProvider).updateGroupList();
  } catch (e, stackTrace) {
    talker.error(
      "Added group \"$trimmed\" but failed to refresh the group list: $e",
      e,
      stackTrace,
    );
  }

  if (context.mounted) context.pop();
}

Future<void> importDictionariesFromFiles(BuildContext context) async {
  if (Platform.isAndroid) {
    if (isFullFlavor()) {
      final isGranted = await requestManageExternalStorage(context);
      if (!isGranted) return;

      final path = await getDirectoryPath();
      if (path == null) return;

      await prefs.setString("dictionariesDirectory", path);

      if (!context.mounted) return;
      showLoadingDialog(context, text: AppLocalizations.of(context)!.loading);

      final paths = await findMdxFilesOnAndroid(path);
      final ifoPaths = await findStardictFilesOnAndroid(path);
      // The loading dialog above is closed by whichever add pipeline
      // runs; when both formats were found, the dialog is shown again
      // for the second one.
      final mdxHandled = paths.isNotEmpty || ifoPaths.isEmpty;
      if (mdxHandled && context.mounted) {
        await selectMdx(context, paths, closeLoadingWhenEmpty: true);
      }
      if (ifoPaths.isNotEmpty && context.mounted) {
        if (mdxHandled) {
          showLoadingDialog(
            context,
            text: AppLocalizations.of(context)!.loading,
          );
        }
        await selectStardict(context, ifoPaths, closeLoadingWhenEmpty: true);
      }
      await addHunspellPairs(await findHunspellPairsOnAndroid(path));
      return;
    }

    PlatformMethod.openDirectory();
    return;
  }

  importDictionaryFilesOnDesktop(context);
}

void showRecommendedDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.explore_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.recommendedDictionaries)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: ListTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: Text(l10n.recommendedDictionaries),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => launchUrl(
                Uri.parse(
                  "https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries",
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text("FreeMDict Cloud"),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => launchUrl(
                Uri.parse(
                  "https://cloud.freemdict.com/index.php/s/pgKcDcbSDTCzXCs",
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text(l10n.close)),
      ],
    ),
  );
}

class AddButton extends StatelessWidget {
  const AddButton({super.key});

  Future<void> _addFromFiles(BuildContext context) {
    return importDictionaryFilesOnDesktop(context);
  }

  Future<void> _addFromDirectories(BuildContext context) {
    return importDictionariesFromDirectoriesOnDesktop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop()) {
      final locale = AppLocalizations.of(context)!;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: locale.import,
            icon: const Icon(Icons.note_add_outlined),
            onPressed: () => _addFromFiles(context),
          ),
          IconButton(
            tooltip: locale.add,
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _addFromDirectories(context),
          ),
        ],
      );
    }

    return IconButton(
      icon: const Icon(Icons.add_rounded),
      tooltip: AppLocalizations.of(context)!.add,
      onPressed: () => importDictionariesFromFiles(context),
    );
  }
}

class DictionaryCard extends ConsumerStatefulWidget {
  final DictionaryListData dictionary;
  final int index;

  const DictionaryCard({
    super.key,
    required this.dictionary,
    required this.index,
  });

  @override
  ConsumerState<DictionaryCard> createState() => _DictionaryCardState();
}

class _DictionaryCardState extends ConsumerState<DictionaryCard> {
  bool _isToggling = false;

  DictionaryListData get dictionary => widget.dictionary;
  int get index => widget.index;

  Future<bool> _checkAndDeleteDictionary(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final missing = await missingDictionaryFile(
      dictionary.path,
      dictionary.type,
    );
    if (missing != null) {
      if (context.mounted) {
        ToastService.show(
          AppLocalizations.of(context)!.dictionaryFileMissing(missing),
          context,
          type: ToastType.error,
        );
      }

      // Ensure it's removed from dictionaryListDao
      await dictionaryListDao.remove(dictionary.path);

      // Try to delete the associated dictionary database file
      final databasePath = join(
        (await databaseDirectory()).path,
        "dictionary_${dictionary.id}.sqlite",
      );
      final dbFile = File(databasePath);
      if (await dbFile.exists()) {
        try {
          await dbFile.delete();
        } catch (e) {
          talker.error(
            "Failed to delete dictionary database file: $e",
            e,
            StackTrace.current,
          );
        }
      }

      // Remove from dictManager if it was loaded
      if (dictManager.contain(dictionary.id)) {
        await dictManager.close(dictionary.id);
      }

      // Remove from all groups
      await dictGroupDao.removeDictIdFromAllGroups(dictionary.id);
      dictManager.dictIds = [
        for (final dict in dictManager.dicts.values) dict.id,
      ];

      // Update UI
      if (context.mounted) {
        ref.read(manageDictionariesModelProvider).update();
        ref.read(dictManagerModelProvider).checkIsEmpty();
      }
      return true;
    }
    return false;
  }

  void _showActionsDialog(BuildContext context, WidgetRef ref, String title) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    Widget buildItem({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? iconColor,
      Color? textColor,
    }) {
      return ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: iconColor ?? theme.colorScheme.primary),
        title: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
        onTap: onTap,
      );
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_stories_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                dictionary.path,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  buildItem(
                    icon: Icons.title_rounded,
                    label: l10n.titleAlias,
                    onTap: () async {
                      if (await _checkAndDeleteDictionary(context, ref)) {
                        if (sheetContext.mounted) sheetContext.pop();
                        return;
                      }
                      if (!sheetContext.mounted) return;
                      sheetContext.pop();
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (context) {
                          final controller = TextEditingController()
                            ..text = title;
                          return AlertDialog(
                            title: Text(l10n.titleAlias),
                            content: TextField(
                              controller: controller,
                              autofocus: true,
                              onSubmitted: (value) async {
                                await _updateAlias(
                                  value,
                                  dictionary,
                                  context,
                                  ref,
                                );
                              },
                            ),
                            actions: [
                              TextButton(
                                onPressed: () async {
                                  try {
                                    if (dictManager.contain(dictionary.id)) {
                                      dictManager.dicts[dictionary.id]!
                                          .setDefaultTitle();
                                      controller.text = dictManager
                                          .dicts[dictionary.id]!
                                          .title;
                                    } else {
                                      final LoadedDictionary dict =
                                          DictionaryType.isStardict(
                                            dictionary.type,
                                          )
                                          ? Stardict(path: dictionary.path)
                                          : Mdict(path: dictionary.path);
                                      try {
                                        await dict.initOnlyMetadata(
                                          dictionary.id,
                                        );
                                        controller.text = dict.title;
                                      } finally {
                                        await dict.close();
                                      }
                                    }
                                  } catch (e, stackTrace) {
                                    talker.error(
                                      "Failed to restore default title: $e",
                                      e,
                                      stackTrace,
                                    );
                                    controller.text = basename(dictionary.path);
                                  }
                                },
                                child: Text(l10n.default_),
                              ),
                              TextButton(
                                onPressed: () => context.pop(),
                                child: Text(l10n.close),
                              ),
                              FilledButton(
                                onPressed: () async {
                                  await _updateAlias(
                                    controller.text,
                                    dictionary,
                                    context,
                                    ref,
                                  );
                                },
                                child: Text(l10n.confirm),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  buildItem(
                    icon: Icons.description_outlined,
                    label: l10n.description,
                    onTap: () async {
                      if (await _checkAndDeleteDictionary(context, ref)) {
                        if (sheetContext.mounted) sheetContext.pop();
                        return;
                      }
                      if (!sheetContext.mounted) return;
                      sheetContext.pop();
                      context.push("/description/${dictionary.id}");
                    },
                  ),
                  buildItem(
                    icon: Icons.info_outline_rounded,
                    label: l10n.properties,
                    onTap: () async {
                      if (await _checkAndDeleteDictionary(context, ref)) {
                        if (sheetContext.mounted) sheetContext.pop();
                        return;
                      }
                      if (!sheetContext.mounted) return;
                      sheetContext.pop();
                      context.push(
                        "/properties",
                        extra: {"path": dictionary.path, "id": dictionary.id},
                      );
                    },
                  ),
                  buildItem(
                    icon: Icons.tune_rounded,
                    label: l10n.settings,
                    onTap: () async {
                      if (await _checkAndDeleteDictionary(context, ref)) {
                        if (sheetContext.mounted) sheetContext.pop();
                        return;
                      }
                      if (!sheetContext.mounted) return;
                      sheetContext.pop();
                      context.push("/settings/dictionary/${dictionary.id}");
                    },
                  ),
                  buildItem(
                    icon: Icons.delete_outline_rounded,
                    label: l10n.remove,
                    iconColor: theme.colorScheme.error,
                    textColor: theme.colorScheme.error,
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (confirmContext) => AlertDialog(
                          title: Text(l10n.remove),
                          content: Text(title),
                          actions: [
                            TextButton(
                              onPressed: () => confirmContext.pop(false),
                              child: Text(l10n.close),
                            ),
                            FilledButton(
                              onPressed: () => confirmContext.pop(true),
                              child: Text(l10n.confirm),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      if (!context.mounted) return;

                      if (await _checkAndDeleteDictionary(context, ref)) {
                        if (sheetContext.mounted) sheetContext.pop();
                        return;
                      }
                      if (dictManager.contain(dictionary.id) &&
                          context.mounted) {
                        final model = ref.read(dictManagerModelProvider);
                        await model.close(dictionary.id);
                        dictManager.dictIds = [
                          for (final dict in dictManager.dicts.values) dict.id,
                        ];
                        model.checkIsEmpty();
                      }

                      await dictGroupDao.removeDictIdFromAllGroups(
                        dictionary.id,
                      );

                      final LoadedDictionary tmpDict =
                          DictionaryType.isStardict(dictionary.type)
                          ? Stardict(path: dictionary.path)
                          : Mdict(path: dictionary.path);
                      await tmpDict.removeDictionary(
                        dictionaryId: dictionary.id,
                      );

                      if (sheetContext.mounted) {
                        ref.read(manageDictionariesModelProvider).update();
                        sheetContext.pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final String title;
    if (dictionary.title != null && dictionary.title != "") {
      title = dictionary.title!;
    } else {
      title = basename(dictionary.path);
    }
    final isEnabled = dictManager.contain(dictionary.id);

    return Card(
      key: ValueKey(dictionary.id),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isEnabled
              ? colorScheme.outlineVariant.withValues(alpha: 0.6)
              : colorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showActionsDialog(context, ref, title),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 6.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.8,
                                )
                              : colorScheme.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 18,
                          color: isEnabled
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isEnabled
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface.withValues(
                                        alpha: 0.65,
                                      ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              basename(dictionary.path),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              color: colorScheme.onSurfaceVariant,
              tooltip: l10n.properties,
              onPressed: () => _showActionsDialog(context, ref, title),
            ),
            Checkbox(
              value: isEnabled,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: _isToggling
                  ? null
                  : (bool? value) async {
                      if (_isToggling) return;
                      setState(() => _isToggling = true);

                      try {
                        if (await _checkAndDeleteDictionary(context, ref)) {
                          return;
                        }

                        if (!context.mounted) return;
                        final model = ref.read(dictManagerModelProvider);

                        if (value == true) {
                          final oldDictionariesNumber =
                              dictManager.dicts.length;

                          await model.add(dictionary.id, dictionary.path);

                          if (oldDictionariesNumber == 0) {
                            if (!context.mounted) return;

                            final searchBarFocusNode = ref
                                .read(homeModelProvider)
                                .searchBarFocusNode;

                            void searchBarFocusListener() {
                              if (searchBarFocusNode.hasFocus) {
                                searchBarFocusNode.unfocus();
                                searchBarFocusNode.removeListener(
                                  searchBarFocusListener,
                                );
                              }
                            }

                            searchBarFocusNode.addListener(
                              searchBarFocusListener,
                            );
                          }
                        } else {
                          await model.close(dictionary.id);
                        }

                        model.checkIsEmpty();

                        await model.updateDictIds();
                      } catch (e, stackTrace) {
                        // Enabling a corrupted dictionary throws; without a
                        // catch the checkbox silently snaps back with no
                        // feedback to the user.
                        talker.error(
                          "Failed to toggle dictionary ${dictionary.id}",
                          e,
                          stackTrace,
                        );
                        if (context.mounted) {
                          ToastService.show(
                            e.toString(),
                            context,
                            type: ToastType.error,
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isToggling = false);
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAlias(
    String value,
    DictionaryListData dictionary,
    BuildContext context,
    WidgetRef ref,
  ) async {
    final trimmed = value.trim();
    final newTitle = trimmed.isEmpty ? null : trimmed;

    if (dictManager.contain(dictionary.id)) {
      if (newTitle == null) {
        dictManager.dicts[dictionary.id]!.setDefaultTitle();
      } else {
        dictManager.dicts[dictionary.id]!.title = newTitle;
      }
    }
    await dictionaryListDao.updateTitle(dictionary.id, newTitle);
    if (context.mounted) {
      ref.read(manageDictionariesModelProvider).update();
      context.pop();
    }
  }
}

class GroupDeleteButton extends ConsumerWidget {
  final DictGroupData group;

  const GroupDeleteButton({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (group.name == "Default") {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      icon: const Icon(Icons.delete_outline_rounded),
      color: Theme.of(context).colorScheme.error,
      tooltip: l10n.remove,
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.remove),
            content: Text(group.name),
            actions: [
              TextButton(
                onPressed: () => dialogContext.pop(false),
                child: Text(l10n.close),
              ),
              FilledButton(
                onPressed: () => dialogContext.pop(true),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        final model = ref.read(dictManagerModelProvider);

        if (group.id == dictManager.groupId) {
          if (group.id == dictManager.groups.last.id) {
            await model.setCurrentGroup(
              dictManager.groups[dictManager.groups.length - 2].id,
            );
          } else {
            final index = dictManager.groups.indexWhere(
              (g) => g.id == group.id,
            );
            await model.setCurrentGroup(dictManager.groups[index + 1].id);
          }
        }

        await dictGroupDao.removeGroup(group.id);
        await model.updateGroupList();
      },
    );
  }
}

class GroupDialog extends ConsumerWidget {
  const GroupDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    // Watch dictManager state so the group list refreshes after add/delete.
    ref.watch(dictManagerModelProvider.select((model) => model.state));

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.collections_bookmark_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.manageGroups)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final group in dictManager.groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Material(
                    color: group.id == dictManager.groupId
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.4,
                          )
                        : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        final targetGroupId = group.id;
                        context.pop();
                        if (targetGroupId != dictManager.groupId) {
                          ref
                              .read(dictManagerModelProvider)
                              .setCurrentGroup(targetGroupId);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              group.id == dictManager.groupId
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: group.id == dictManager.groupId
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                group.name == "Default"
                                    ? l10n.default_
                                    : group.name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: group.id == dictManager.groupId
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            GroupDeleteButton(group: group),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text(l10n.close)),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.add),
          onPressed: () {
            // This dialog is popped right below, so its own context must not
            // be used to push the next one: keep the navigator instead.
            final navigatorContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;
            context.pop();
            showDialog(
              context: navigatorContext,
              builder: (context) {
                final controller = TextEditingController();
                return AlertDialog(
                  title: Text(l10n.add),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    onSubmitted: (String groupName) async {
                      await addGroup(groupName, context);
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text(l10n.close),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await addGroup(controller.text, context);
                      },
                      child: Text(l10n.confirm),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class InfoButton extends StatelessWidget {
  const InfoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline_rounded),
      tooltip: AppLocalizations.of(context)!.recommendedDictionaries,
      onPressed: () => showRecommendedDialog(context),
    );
  }
}

class _GroupStatusBar extends StatelessWidget {
  final String groupName;
  final int enabledCount;
  final int totalCount;
  final VoidCallback onTap;

  const _GroupStatusBar({
    required this.groupName,
    required this.enabledCount,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Material(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.collections_bookmark_rounded,
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              groupName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "$enabledCount / $totalCount",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.manageGroups,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ManageDictionariesPage extends StatefulWidget {
  const ManageDictionariesPage({super.key});

  @override
  State<ManageDictionariesPage> createState() => ManageDictionariesPageState();
}

class ManageDictionariesBody extends ConsumerWidget {
  const ManageDictionariesBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dictionaries = ref.watch(
      manageDictionariesModelProvider.select((model) => model.dictionaries),
    );
    // Watch dictManager state so the enabled-count in _GroupStatusBar
    // refreshes when dictionaries are enabled/disabled. Without this,
    // the "x/y" count stays stale after toggling.
    ref.watch(dictManagerModelProvider.select((model) => model.state));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder(
      future: dictionaries,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<DictionaryListData>> snapshot,
          ) {
            if (snapshot.hasData) {
              final dicts = snapshot.data!;
              if (dicts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_stories_outlined,
                            size: 40,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.empty,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.addDictionary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: () =>
                                  importDictionariesFromFiles(context),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(l10n.add),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => showRecommendedDialog(context),
                              icon: const Icon(
                                Icons.explore_outlined,
                                size: 18,
                              ),
                              label: Text(l10n.recommendedDictionaries),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                final currentGroup = dictManager.groups.firstWhere(
                  (g) => g.id == dictManager.groupId,
                  orElse: () => dictManager.groups.isNotEmpty
                      ? dictManager.groups.first
                      : const DictGroupData(
                          id: 0,
                          name: "Default",
                          dictIds: "[]",
                        ),
                );
                final groupName = currentGroup.name == "Default"
                    ? l10n.default_
                    : currentGroup.name;

                return Column(
                  children: [
                    _GroupStatusBar(
                      groupName: groupName,
                      enabledCount: dictManager.dicts.length,
                      totalCount: dicts.length,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const GroupDialog(),
                        );
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ReorderableListView(
                          // See the Hunspell page: edge-to-edge window, so the
                          // navigation bar would cover the last dictionary.
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.viewPaddingOf(context).bottom,
                          ),
                          buildDefaultDragHandles: false,
                          onReorderItem: (oldIndex, newIndex) {
                            final dict = dicts.removeAt(oldIndex);
                            dicts.insert(newIndex, dict);

                            ref
                                .read(manageDictionariesModelProvider)
                                .updateWithList(dicts);

                            () async {
                              await dictionaryListDao.updateOrder(dicts);

                              if (context.mounted) {
                                final model = ref.read(
                                  dictManagerModelProvider,
                                );
                                await model.updateDictIds();
                              }
                            }();
                          },
                          children: [
                            for (int i = 0; i < dicts.length; i++)
                              DictionaryCard(
                                key: ValueKey(dicts[i].id),
                                dictionary: dicts[i],
                                index: i,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
    );
  }
}

class ManageDictionariesModel extends ChangeNotifier {
  Future<List<DictionaryListData>> dictionaries = dictionaryListDao.all();

  void update() {
    dictionaries = dictionaryListDao.all();
    notifyListeners();
  }

  void updateWithList(List<DictionaryListData> dicts) {
    dictionaries = Future.value(dicts);
    notifyListeners();
  }
}

class ManageDictionariesPageState extends State<ManageDictionariesPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageDictionaries),
        actions: [
          const GroupButton(),
          if (Platform.isAndroid) const UpdateButton(),
          const InfoButton(),
          const AddButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Consumer(
            builder: (context, ref, child) {
              ref.watch(
                dictManagerModelProvider.select((model) => model.state),
              );
              return const ManageDictionariesBody();
            },
          ),
        ),
      ),
    );
  }
}

class GroupButton extends StatelessWidget {
  const GroupButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context)!.manageGroups,
      onPressed: () {
        showDialog(context: context, builder: (context) => const GroupDialog());
      },
      icon: const Icon(Icons.collections_bookmark_rounded),
    );
  }
}

class UpdateButton extends StatelessWidget {
  const UpdateButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Refresh",
      icon: const Icon(Icons.refresh_rounded),
      onPressed: () {
        PlatformMethod.updateDictionaries();
      },
    );
  }
}

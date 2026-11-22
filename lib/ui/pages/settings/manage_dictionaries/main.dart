import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/dictionary_files.dart";
import "package:ciyue/repositories/hunspell.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/loading_dialog.dart";
import "package:ciyue/ui/pages/settings/personal_dictionary/personal_dictionary_io.dart";
import "package:ciyue/utils.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:path/path.dart";
import "package:url_launcher/url_launcher.dart";

/// Shows the name dialog for a new personal dictionary, or for renaming
/// [dictionary] when given. An empty, too-long or duplicate name is
/// rejected with an inline error and the dialog stays open. On success the
/// dictionary list refreshes and a toast confirms the change.
Future<void> showPersonalDictionaryNameDialog(
  BuildContext context,
  DictionaryListData? dictionary,
) async {
  await showDialog(
    context: context,
    builder: (dialogContext) =>
        _PersonalDictionaryNameDialog(dictionary: dictionary),
  );
}

/// The name dialog itself: a stateful widget so its [TextEditingController]
/// is disposed with the dialog instead of leaking on every open.
class _PersonalDictionaryNameDialog extends StatefulWidget {
  const _PersonalDictionaryNameDialog({required this.dictionary});

  final DictionaryListData? dictionary;

  @override
  State<_PersonalDictionaryNameDialog> createState() =>
      _PersonalDictionaryNameDialogState();
}

class _PersonalDictionaryNameDialogState
    extends State<_PersonalDictionaryNameDialog> {
  late final TextEditingController _controller;
  String? _nameError;

  bool get _isRename => widget.dictionary != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.dictionary?.title ?? "");
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext dialogContext, String value) async {
    final l10n = AppLocalizations.of(dialogContext)!;
    final name = value.trim();
    if (name.isEmpty) {
      setState(() => _nameError = l10n.personalDictionaryNameEmpty);
      return;
    }
    if (name.length > personalDictionaryNameMaxLength) {
      setState(
        () => _nameError = l10n.personalDictionaryNameTooLong(
          personalDictionaryNameMaxLength,
        ),
      );
      return;
    }

    final container = ProviderScope.containerOf(dialogContext, listen: false);
    final service = container.read(personalDictionaryServiceProvider);
    if (await service.dictionaryNameExists(
      name,
      exceptId: _isRename ? widget.dictionary!.id : null,
    )) {
      setState(() => _nameError = l10n.personalDictionaryNameAlreadyExists);
      return;
    }
    setState(() => _nameError = null);

    try {
      if (_isRename) {
        final dictionary = widget.dictionary!;
        final model = container.read(dictManagerModelProvider);
        // Mirror _updateAlias for file dictionaries: the loaded
        // dictionary keeps its own title, so sync it first — that is
        // what the word page tabs read — and notify, then persist.
        if (dictManager.contain(dictionary.id)) {
          dictManager.dicts[dictionary.id]!.title = name;
          model.update();
        }
        await service.renameDictionary(dictionary.id, name);
      } else {
        final id = await service.createDictionary(name);
        // A new dictionary is useless until it is loaded: the lookup only
        // sees dictionaries in the manager, and the group only keeps the
        // ids written back to it. This is the enable path a file
        // dictionary takes when its checkbox is ticked.
        final model = container.read(dictManagerModelProvider);
        await model.add(id, "personal:$id");
        await model.updateDictIds();
      }
    } catch (e, stackTrace) {
      talker.error(
        "Failed to ${_isRename ? "rename" : "create"} personal dictionary",
        e,
        stackTrace,
      );
      if (!dialogContext.mounted) return;
      // The service can still reject the name (a race with another
      // create): map that onto the same inline error. Anything else is
      // a generic failure toast, never the raw exception text.
      final message = e.toString();
      if (message.contains("already exists")) {
        setState(() => _nameError = l10n.personalDictionaryNameAlreadyExists);
      } else if (message.contains("at most")) {
        setState(
          () => _nameError = l10n.personalDictionaryNameTooLong(
            personalDictionaryNameMaxLength,
          ),
        );
      } else {
        unawaited(
          ToastService.show(
            l10n.personalDictionaryOperationFailed,
            dialogContext,
            type: ToastType.error,
          ),
        );
      }
      return;
    }

    container.read(manageDictionariesModelProvider).update();
    if (dialogContext.mounted) {
      unawaited(
        ToastService.show(
          _isRename
              ? l10n.personalDictionaryRenamed
              : l10n.personalDictionaryCreated,
          dialogContext,
        ),
      );
      Navigator.of(dialogContext).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        _isRename ? l10n.personalDictionaryRename : l10n.personalDictionaryNew,
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        // The same 100-character cap the service enforces, but the
        // field must not enforce it: silently truncating what the user
        // typed would create a name they never entered. Over-long input
        // stays in the field so _submit can reject it with the inline
        // error, the same as a duplicate name. No counter: the cap is a
        // guard, not a budget the user tracks.
        maxLength: personalDictionaryNameMaxLength,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        decoration: InputDecoration(
          labelText: l10n.personalDictionaryName,
          errorText: _nameError,
          counterText: "",
        ),
        onSubmitted: (value) => _submit(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
        FilledButton(
          onPressed: () => _submit(context, _controller.text),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

class NewPersonalDictionaryButton extends StatelessWidget {
  const NewPersonalDictionaryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context)!.personalDictionaryNew,
      icon: const Icon(Icons.post_add_rounded),
      onPressed: () => showPersonalDictionaryNameDialog(context, null),
    );
  }
}

Future<void> addGroup(String value, BuildContext context) async {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return;

  final existingGroups = await dictGroupDao.getAllGroups();
  final alreadyExists = existingGroups.any(
    (g) => g.name.toLowerCase() == trimmed.toLowerCase(),
  );

  if (alreadyExists) {
    if (context.mounted) {
      await ToastService.show(
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
      await ToastService.show(
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

      // Resolve the picked tree natively instead of file_selector's
      // getDirectoryPath(), whose path resolution throws for non-"primary"
      // volumes (SD cards, USB drives: #800) and used to fail silently.
      final pick = await PlatformMethod.pickDictionaryDirectoryPath();
      if (pick.cancelled) return;
      final path = pick.path;
      if (path == null) {
        // Resolution failed: fall back to the SAF-copy flow (the
        // non-full-flavor path). Do not save the pref or run the direct
        // scan below; the fallback's inputDirectory handler saves the
        // picked URI itself, as it does for the non-full flavor.
        await PlatformMethod.openDirectory();
        return;
      }

      await prefs.setString("dictionariesDirectory", path);

      if (!context.mounted) return;
      showLoadingDialog(context, text: AppLocalizations.of(context)!.loading);

      final paths = await findMdxFilesOnAndroid(path);
      final ifoPaths = await findStardictFilesOnAndroid(path);
      final zimPaths = await findZimFilesOnAndroid(path);
      // The loading dialog above is closed by whichever add pipeline
      // runs; when multiple formats were found, the dialog is shown again
      // for the subsequent ones.
      final mdxHandled =
          paths.isNotEmpty || (ifoPaths.isEmpty && zimPaths.isEmpty);
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
      if (zimPaths.isNotEmpty && context.mounted) {
        if (mdxHandled || ifoPaths.isNotEmpty) {
          showLoadingDialog(
            context,
            text: AppLocalizations.of(context)!.loading,
          );
        }
        await selectZim(context, zimPaths, closeLoadingWhenEmpty: true);
      }
      await addHunspellPairs(await findHunspellPairsOnAndroid(path));
      return;
    }

    await PlatformMethod.openDirectory();
    return;
  }

  await importDictionaryFilesOnDesktop(context);
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

  /// Entry count for personal dictionaries, fetched once per card.
  Future<int>? _personalEntryCount;

  DictionaryListData get dictionary => widget.dictionary;
  int get index => widget.index;

  @override
  void initState() {
    super.initState();
    if (DictionaryType.isPersonal(dictionary.type)) {
      _personalEntryCount = ref
          .read(personalDictionaryServiceProvider)
          .entryCount(dictionary.id);
    }
  }

  void _refreshPersonalEntryCount() {
    setState(() {
      _personalEntryCount = ref
          .read(personalDictionaryServiceProvider)
          .entryCount(dictionary.id);
    });
  }

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
        await ToastService.show(
          AppLocalizations.of(context)!.dictionaryFileMissing(missing),
          context,
          type: ToastType.error,
        );
      }

      await dictionaryListDao.remove(dictionary.path);

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

      if (dictManager.contain(dictionary.id)) {
        await dictManager.close(dictionary.id);
      }

      await dictGroupDao.removeDictIdFromAllGroups(dictionary.id);
      dictManager.dictIds = [
        for (final dict in dictManager.dicts.values) dict.id,
      ];

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
                                      final dict = createLoadedDictionary(
                                        path: dictionary.path,
                                        type: dictionary.type,
                                      );
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
                      await context.push("/description/${dictionary.id}");
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
                      await context.push(
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
                      await context.push(
                        "/settings/dictionary/${dictionary.id}",
                      );
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

                      final tmpDict = createLoadedDictionary(
                        path: dictionary.path,
                        type: dictionary.type,
                      );
                      await tmpDict.removeDictionary(
                        dictionaryId: dictionary.id,
                      );

                      try {
                        await ref
                            .read(fullTextSearchServiceProvider)
                            .dropDictionary(dictionary.id);
                      } catch (e, stackTrace) {
                        talker.error(
                          "Failed to drop full-text index for dictionary "
                          "${dictionary.id}: $e",
                          e,
                          stackTrace,
                        );
                      }

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

  void _openPersonalEntries(BuildContext context, String title) {
    unawaited(
      context
          .push(
            "/settings/personal_dictionary/${dictionary.id}",
            extra: {"title": title},
          )
          .then((_) {
            if (mounted) _refreshPersonalEntryCount();
          }),
    );
  }

  void _showPersonalActionsSheet(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) {
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
                            Icons.edit_note_rounded,
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
                              FutureBuilder<int>(
                                future: _personalEntryCount,
                                builder: (context, snapshot) {
                                  final count = snapshot.data;
                                  return Text(
                                    count == null
                                        ? ""
                                        : l10n.personalDictionaryEntryCount(
                                            count,
                                          ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
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
                    icon: Icons.list_alt_rounded,
                    label: l10n.personalDictionaryEditEntries,
                    onTap: () {
                      sheetContext.pop();
                      _openPersonalEntries(context, title);
                    },
                  ),
                  buildItem(
                    icon: Icons.file_download_outlined,
                    label: l10n.personalDictionaryImportDsl,
                    onTap: () {
                      sheetContext.pop();
                      unawaited(
                        importPersonalDictionaryDsl(
                          context,
                          ref.read(personalDictionaryServiceProvider),
                          dictionary.id,
                        ).then((_) {
                          if (mounted) _refreshPersonalEntryCount();
                        }),
                      );
                    },
                  ),
                  buildItem(
                    icon: Icons.file_upload_outlined,
                    label: l10n.personalDictionaryExportDsl,
                    onTap: () {
                      sheetContext.pop();
                      unawaited(
                        exportPersonalDictionaryDsl(
                          context,
                          ref.read(personalDictionaryServiceProvider),
                          dictionary.id,
                          title,
                        ),
                      );
                    },
                  ),
                  buildItem(
                    icon: Icons.title_rounded,
                    label: l10n.personalDictionaryRename,
                    onTap: () {
                      sheetContext.pop();
                      unawaited(
                        showPersonalDictionaryNameDialog(context, dictionary),
                      );
                    },
                  ),
                  buildItem(
                    icon: Icons.delete_outline_rounded,
                    label: l10n.personalDictionaryDelete,
                    iconColor: theme.colorScheme.error,
                    textColor: theme.colorScheme.error,
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (confirmContext) => AlertDialog(
                          title: Text(l10n.personalDictionaryDelete),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.personalDictionaryDeleteConfirm),
                              const SizedBox(height: 8),
                              Text(title),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(confirmContext).pop(false),
                              child: Text(l10n.close),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(confirmContext).pop(true),
                              child: Text(l10n.confirm),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;

                      // Close first, mirroring the file-dictionary
                      // delete: while the rows still exist a lookup can
                      // still resolve, and close marks the dictionary
                      // closed before an initialization still in flight
                      // can bind a server nobody closes again (P1-4).
                      // Deleting the rows first left lookups hitting a
                      // loaded dictionary whose articles were already
                      // gone.
                      final model = ref.read(dictManagerModelProvider);
                      if (dictManager.contain(dictionary.id)) {
                        await model.close(dictionary.id);
                      }

                      try {
                        await ref
                            .read(personalDictionaryServiceProvider)
                            .deleteDictionary(dictionary.id);
                      } catch (e, stackTrace) {
                        talker.error(
                          "Failed to delete personal dictionary "
                          "${dictionary.id}",
                          e,
                          stackTrace,
                        );
                        if (context.mounted) {
                          unawaited(
                            ToastService.show(
                              l10n.personalDictionaryOperationFailed,
                              context,
                              type: ToastType.error,
                            ),
                          );
                        }
                        return;
                      }

                      await dictGroupDao.removeDictIdFromAllGroups(
                        dictionary.id,
                      );

                      // Persist the enabled set and notify the word pages
                      // whether or not the dictionary was loaded: the old
                      // code kept this inside the `contain` block, so
                      // deleting a disabled dictionary never wrote the
                      // group list back or re-ran the lookups.
                      // `updateDictIds` also runs `checkIsEmpty`.
                      await model.updateDictIds();

                      if (sheetContext.mounted) {
                        ref.read(manageDictionariesModelProvider).update();
                        sheetContext.pop();
                      }
                      if (context.mounted) {
                        unawaited(
                          ToastService.show(
                            l10n.personalDictionaryDeleted,
                            context,
                          ),
                        );
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

  Widget _buildPersonalCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    // A personal dictionary's path is the `personal:<id>` sentinel, never
    // a file name, so it is only a fallback when no title was stored.
    final title = dictionary.title != null && dictionary.title != ""
        ? dictionary.title!
        : dictionary.path;
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
                onTap: () => _openPersonalEntries(context, title),
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
                          Icons.edit_note_rounded,
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
                            FutureBuilder<int>(
                              future: _personalEntryCount,
                              builder: (context, snapshot) {
                                final count = snapshot.data;
                                return Text(
                                  count == null
                                      ? ""
                                      : l10n.personalDictionaryEntryCount(
                                          count,
                                        ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                        if (!context.mounted) return;
                        final model = ref.read(dictManagerModelProvider);
                        if (value == true) {
                          final oldDictionariesNumber =
                              dictManager.dicts.length;

                          if (dictManager.isLoading) {
                            // The switch that loads this group is still
                            // running, and enabling now only sticks once it
                            // has finished. Say so instead of leaving the
                            // checkbox looking ignored for a while.
                            unawaited(
                              ToastService.show(
                                l10n.dictionaryEnabledAfterLoading,
                                context,
                                type: ToastType.info,
                              ),
                            );
                          }

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
                          unawaited(
                            ToastService.show(
                              l10n.personalDictionaryOperationFailed,
                              context,
                              type: ToastType.error,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isToggling = false);
                        }
                      }
                    },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              color: colorScheme.onSurfaceVariant,
              tooltip: l10n.more,
              onPressed: () => _showPersonalActionsSheet(context, ref, title),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Personal dictionaries have no files to reorder: they get
    // their own card with an entry count and personal actions instead.
    // Enabling one loads it into the manager like a file dictionary.
    if (DictionaryType.isPersonal(dictionary.type)) {
      return _buildPersonalCard(context, theme, colorScheme, l10n);
    }

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

                          if (dictManager.isLoading) {
                            // The switch that loads this group is still
                            // running, and enabling now only sticks once it
                            // has finished. Say so instead of leaving the
                            // checkbox looking ignored for a while.
                            unawaited(
                              ToastService.show(
                                l10n.dictionaryEnabledAfterLoading,
                                context,
                                type: ToastType.info,
                              ),
                            );
                          }

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
                          await ToastService.show(
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

class _GroupTile extends ConsumerWidget {
  final DictGroupData group;
  final int index;

  const _GroupTile({super.key, required this.group, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isCurrent = group.id == dictManager.groupId;
    final isDefault = group.name == "Default";

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Material(
        color: isCurrent
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final targetGroupId = group.id;
                  context.pop();
                  if (targetGroupId != dictManager.groupId) {
                    unawaited(
                      ref
                          .read(dictManagerModelProvider)
                          .setCurrentGroup(targetGroupId),
                    );
                  }
                },
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    // The delete button fills the right side of the other
                    // groups, but the default one has none.
                    right: isDefault ? 12 : 0,
                    top: 8,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCurrent
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isDefault ? l10n.default_ : group.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isCurrent
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
            // The default group is created at first run and always stays on
            // top, so it cannot be dragged.
            if (!isDefault)
              ReorderableDragStartListener(
                index: index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 10.0,
                    ),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
        child: ReorderableListView(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          onReorderItem: (oldIndex, newIndex) {
            unawaited(
              ref.read(dictManagerModelProvider).moveGroup(oldIndex, newIndex),
            );
          },
          children: [
            for (int i = 0; i < dictManager.groups.length; i++)
              _GroupTile(
                key: ValueKey(dictManager.groups[i].id),
                group: dictManager.groups[i],
                index: i,
              ),
          ],
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
                            // The AppBar's new-dictionary button is still
                            // there, but an empty list is exactly where a
                            // first-time user looks for a way in — offer
                            // the same create flow here.
                            OutlinedButton.icon(
                              onPressed: () => showPersonalDictionaryNameDialog(
                                context,
                                null,
                              ),
                              icon: const Icon(
                                Icons.post_add_rounded,
                                size: 18,
                              ),
                              label: Text(l10n.personalDictionaryNew),
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
                          hunspellIds: "",
                          order: 0,
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

                            unawaited(() async {
                              await dictionaryListDao.updateOrder(dicts);

                              if (context.mounted) {
                                final model = ref.read(
                                  dictManagerModelProvider,
                                );
                                await model.updateDictIds();
                              }
                            }());
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
          IconButton(
            tooltip: l10n.fullTextIndexOverview,
            icon: const Icon(Icons.manage_search_rounded),
            onPressed: () => context.push("/full-text-index-overview"),
          ),
          const AddButton(),
          const NewPersonalDictionaryButton(),
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
      tooltip: AppLocalizations.of(context)!.refresh,
      icon: const Icon(Icons.refresh_rounded),
      onPressed: () {
        unawaited(PlatformMethod.updateDictionaries());
      },
    );
  }
}

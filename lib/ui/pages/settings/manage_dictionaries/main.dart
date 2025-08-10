import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/loading_dialog.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:file_selector/file_selector.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:path/path.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

Future<void> addGroup(String value, BuildContext context) async {
  if (value.isNotEmpty) {
    await dictGroupDao.addGroup(value, []);

    if (context.mounted) {
      final model = context.read<DictManagerModel>();
      await model.updateGroupList();
    }
    if (context.mounted) {
      context.pop();
    }
  }
}

class AddButton extends StatelessWidget {
  const AddButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add),
      onPressed: () async {
        if (Platform.isAndroid) {
          if (isFullFlavor()) {
            final isGranted = await requestManageExternalStorage(context);
            if (!isGranted) return;

            final path = await getDirectoryPath();
            if (path == null) return;

            await prefs.setString("dictionariesDirectory", path);

            if (!context.mounted) return;
            showLoadingDialog(context,
                text: AppLocalizations.of(context)!.loading);

            final paths = await findMdxFilesOnAndroid(path);
            if (context.mounted) await selectMdx(context, paths);
            return;
          }

          PlatformMethod.openDirectory();
          return;
        }

        selectMdxOrMddOnDesktop(context, true);
      },
    );
  }
}

class DictionaryCard extends StatelessWidget {
  final DictionaryListData dictionary;
  final int index;

  const DictionaryCard({
    super.key,
    required this.dictionary,
    required this.index,
  });

  Future<bool> _checkAndDeleteDictionary(BuildContext context) async {
    final mdxFile = File("${dictionary.path}.mdx");
    if (!await mdxFile.exists()) {
      if (context.mounted) {
        ToastService.show(
            AppLocalizations.of(context)!.dictionaryFileNotFound, context,
            type: ToastType.error);
      }

      // Ensure it's removed from dictionaryListDao
      await dictionaryListDao.remove(dictionary.path);

      // Try to delete the associated dictionary database file
      final databasePath = join((await databaseDirectory()).path,
          "dictionary_${dictionary.id}.sqlite");
      final dbFile = File(databasePath);
      if (await dbFile.exists()) {
        try {
          await dbFile.delete();
        } catch (e) {
          talker.error("Failed to delete dictionary database file: $e", e,
              StackTrace.current);
        }
      }

      // Remove from dictManager if it was loaded
      if (dictManager.contain(dictionary.id)) {
        await dictManager.close(dictionary.id);
      }

      // Update dictIds in the current group
      final dictIds = [for (final dict in dictManager.dicts.values) dict.id];
      dictManager.dictIds = dictIds;
      await dictGroupDao.updateDictIds(dictManager.groupId, dictIds);

      // Update UI
      if (context.mounted) {
        context.read<ManageDictionariesModel>().update();
        context.read<DictManagerModel>().checkIsEmpty();
      }
      return true;
    }
    return false;
  }

  void _showActionsDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(title),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () async {
                if (await _checkAndDeleteDictionary(context)) {
                  if (context.mounted) context.pop();
                  return;
                }
                if (!context.mounted) return;
                context.pop();
                context.push("/properties",
                    extra: {"path": dictionary.path, "id": dictionary.id});
              },
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text(AppLocalizations.of(context)!.properties),
              ),
            ),
            SimpleDialogOption(
              onPressed: () async {
                if (await _checkAndDeleteDictionary(context)) {
                  if (context.mounted) context.pop();
                  return;
                }
                // Existing remove logic
                if (dictManager.contain(dictionary.id) && context.mounted) {
                  final model = context.read<DictManagerModel>();
                  await model.close(dictionary.id);

                  final dictIds = [
                    for (final dict in dictManager.dicts.values) dict.id
                  ];
                  dictManager.dictIds = dictIds;

                  model.checkIsEmpty();

                  await dictGroupDao.updateDictIds(
                      dictManager.groupId, dictIds);
                }

                final tmpDict = Mdict(path: dictionary.path);
                // No need to init if file is already gone, _checkAndDeleteDictionary handles it.
                // If file exists, init will succeed.
                await tmpDict.init();
                await tmpDict.removeDictionary();
                await tmpDict.close();

                if (context.mounted) {
                  context.read<ManageDictionariesModel>().update();
                  context.pop();
                }
              },
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text(AppLocalizations.of(context)!.remove),
              ),
            ),
            SimpleDialogOption(
              onPressed: () async {
                if (await _checkAndDeleteDictionary(context)) {
                  if (context.mounted) context.pop();
                  return;
                }
                if (!context.mounted) return;
                context.pop();
                context.push("/description/${dictionary.id}");
              },
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text(AppLocalizations.of(context)!.description),
              ),
            ),
            SimpleDialogOption(
              onPressed: () async {
                if (await _checkAndDeleteDictionary(context)) {
                  if (context.mounted) context.pop();
                  return;
                }
                if (!context.mounted) return;
                context.pop();
                context.push("/settings/dictionary/${dictionary.id}");
              },
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text(AppLocalizations.of(context)!.settings),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                context.pop();
                showDialog(
                  context: context,
                  builder: (context) {
                    final controller = TextEditingController();
                    return AlertDialog(
                      title: Text(AppLocalizations.of(context)!.titleAlias),
                      content: TextField(
                        controller: controller..text = title,
                        autofocus: true,
                        onSubmitted: (value) async {
                          await _updateAlias(value, dictionary, context);
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            if (dictManager.contain(dictionary.id)) {
                              dictManager.dicts[dictionary.id]!
                                  .setDefaultTitle();
                              controller.text =
                                  dictManager.dicts[dictionary.id]!.title;
                            } else {
                              final dict = Mdict(path: dictionary.path);
                              await dict.initOnlyMetadata(dictionary.id);
                              controller.text = dict.title;
                            }
                          },
                          child: Text(AppLocalizations.of(context)!.default_),
                        ),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: Text(AppLocalizations.of(context)!.close),
                        ),
                        TextButton(
                            onPressed: () async {
                              await _updateAlias(
                                  controller.text, dictionary, context);
                            },
                            child: Text(AppLocalizations.of(context)!.confirm)),
                      ],
                    );
                  },
                );
              },
              child: ListTile(
                leading: Icon(Icons.title),
                title: Text(AppLocalizations.of(context)!.titleAlias),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final String title;
    if (dictionary.title != null || dictionary.title != "") {
      title = dictionary.title!;
    } else {
      title = basename(dictionary.path);
    }

    return Card(
      key: ValueKey(dictionary.id),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.onInverseSurface,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: IconButton(
                  icon: Icon(Icons.drag_handle), onPressed: () => {}),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _showActionsDialog(context, title),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Checkbox(
              value: dictManager.contain(dictionary.id),
              onChanged: (bool? value) async {
                if (await _checkAndDeleteDictionary(context)) {
                  return;
                }

                if (!context.mounted) return;
                final model = context.read<DictManagerModel>();

                if (value == true) {
                  final oldDictionariesNumber = dictManager.dicts.length;

                  await model.add(dictionary.id, dictionary.path);

                  if (oldDictionariesNumber == 0) {
                    if (!context.mounted) return;

                    final searchBarFocusNode =
                        context.read<HomeModel>().searchBarFocusNode;

                    void searchBarFocusListener() {
                      if (searchBarFocusNode.hasFocus) {
                        searchBarFocusNode.unfocus();
                        searchBarFocusNode
                            .removeListener(searchBarFocusListener);
                      }
                    }

                    searchBarFocusNode.addListener(searchBarFocusListener);
                  }
                } else {
                  await model.close(dictionary.id);
                }

                model.checkIsEmpty();

                await model.updateDictIds();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAlias(
      String value, DictionaryListData dictionary, BuildContext context) async {
    if (value.isNotEmpty) {
      if (dictManager.contain(dictionary.id)) {
        dictManager.dicts[dictionary.id]!.title = value;
      }
      await dictionaryListDao.updateTitle(dictionary.id, value);
      if (context.mounted) {
        context.read<ManageDictionariesModel>().update();
        context.pop();
      }
    }
  }
}

class GroupDeleteButton extends StatelessWidget {
  final DictGroupData group;

  const GroupDeleteButton({
    super.key,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    if (group.name == "Default") {
      return SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.delete),
      onPressed: () async {
        final model = context.read<DictManagerModel>();

        if (group.id == dictManager.groupId) {
          if (group.id == dictManager.groups.last.id) {
            await model.setCurrentGroup(
                dictManager.groups[dictManager.groups.length - 2].id);
          } else {
            final index =
                dictManager.groups.indexWhere((g) => g.id == group.id);
            await model.setCurrentGroup(dictManager.groups[index + 1].id);
          }
        }

        await dictGroupDao.removeGroup(group.id);
        await model.updateGroupList();

        if (context.mounted) context.pop();
      },
    );
  }
}

class GroupDialog extends StatelessWidget {
  const GroupDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.manageGroups),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final group in dictManager.groups)
            RadioListTile(
              title: Text(group.name == "Default"
                  ? AppLocalizations.of(context)!.default_
                  : group.name),
              value: group.id,
              groupValue: dictManager.groupId,
              secondary: GroupDeleteButton(group: group),
              onChanged: (int? groupId) async {
                if (groupId != dictManager.groupId) {
                  final model = context.read<DictManagerModel>();
                  await model.setCurrentGroup(groupId!);
                }
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(AppLocalizations.of(context)!.close),
        ),
        TextButton(
          onPressed: () {
            context.pop();
            showDialog(
              context: context,
              builder: (context) {
                final controller = TextEditingController();
                return AlertDialog(
                  title: Text(AppLocalizations.of(context)!.add),
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
                      child: Text(AppLocalizations.of(context)!.close),
                    ),
                    TextButton(
                        onPressed: () async {
                          await addGroup(controller.text, context);
                        },
                        child: Text(AppLocalizations.of(context)!.add)),
                  ],
                );
              },
            );
          },
          child: Text(AppLocalizations.of(context)!.add),
        ),
      ],
    );
  }
}

class InfoButton extends StatelessWidget {
  const InfoButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.recommendedDictionaries),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                      AppLocalizations.of(context)!.recommendedDictionaries),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrl(Uri.parse(
                      "https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries")),
                ),
                ListTile(
                  title: const Text("FreeMDict Cloud"),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrl(Uri.parse(
                      "https://cloud.freemdict.com/index.php/s/pgKcDcbSDTCzXCs")),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text(AppLocalizations.of(context)!.close),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ManageDictionariesPage extends StatefulWidget {
  const ManageDictionariesPage({super.key});

  @override
  State<ManageDictionariesPage> createState() => ManageDictionariesPageState();
}

class ManageDictionariesBody extends StatelessWidget {
  const ManageDictionariesBody({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    context.select<ManageDictionariesModel, Future<List<DictionaryListData>>>(
        (model) => model.dictionaries);

    return FutureBuilder(
      future: context.read<ManageDictionariesModel>().dictionaries,
      builder: (BuildContext context,
          AsyncSnapshot<List<DictionaryListData>> snapshot) {
        if (snapshot.hasData) {
          final dicts = snapshot.data!;
          if (dicts.isEmpty) {
            return Center(
                child: Text(
              AppLocalizations.of(context)!.empty,
              style: Theme.of(context).textTheme.titleLarge,
            ));
          } else {
            return Padding(
              padding: const EdgeInsets.only(
                left: 8.0,
                right: 8.0,
              ),
              child: ReorderableListView(
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }

                  final dict = dicts.removeAt(oldIndex);
                  dicts.insert(newIndex, dict);

                  context.read<ManageDictionariesModel>().updateWithList(dicts);

                  () async {
                    await dictionaryListDao.updateOrder(dicts);

                    if (context.mounted) {
                      final model = context.read<DictManagerModel>();
                      await model.updateDictIds();
                    }
                  }();
                },
                children: [
                  for (int i = 0; i < dicts.length; i++)
                    DictionaryCard(
                        key: ValueKey(dicts[i].id),
                        dictionary: dicts[i],
                        index: i)
                ],
              ),
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
    return Scaffold(
      appBar: AppBar(actions: [
        const GroupButton(),
        if (Platform.isAndroid) const UpdateButton(),
        const InfoButton(),
        const AddButton(),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Selector<DictManagerModel, int>(
            selector: (context, model) => model.state,
            builder: (context, value, child) {
              return ManageDictionariesBody();
            },
          ),
        ),
      ),
    );
  }
}

class GroupButton extends StatelessWidget {
  const GroupButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => GroupDialog(),
          );
        },
        icon: Icon(Icons.group));
  }
}

class UpdateButton extends StatelessWidget {
  const UpdateButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.refresh),
      onPressed: () {
        PlatformMethod.updateDictionaries();
      },
    );
  }
}

import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/main.dart";
import "package:ciyue/services/dictionary.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/dictionary.dart";
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
      onPressed: () {
        if (Platform.isAndroid) {
          PlatformMethod.openDirectory();
        } else {
          selectMdxOrMdd(context, true);
        }
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = dictionary.alias ??
        (dictManager.contain(dictionary.id)
            ? dictManager.dicts[dictionary.id]!.title
            : basename(dictionary.path));

    return Card(
      key: ValueKey(dictionary.id),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.onInverseSurface,
      child: GestureDetector(
          onLongPress: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return SimpleDialog(
                  title: Text(title),
                  children: <Widget>[
                    SimpleDialogOption(
                      onPressed: () {
                        context.pop();
                        context.push("/properties", extra: {
                          "path": dictionary.path,
                          "id": dictionary.id
                        });
                      },
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text(AppLocalizations.of(context)!.properties),
                      ),
                    ),
                    SimpleDialogOption(
                      onPressed: () async {
                        if (dictManager.contain(dictionary.id)) {
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
                      onPressed: () {
                        context.pop();
                        context.push("/description/${dictionary.id}");
                      },
                      child: ListTile(
                        leading: Icon(Icons.info),
                        title: Text(AppLocalizations.of(context)!.description),
                      ),
                    ),
                    SimpleDialogOption(
                      onPressed: () {
                        context.pop();
                        context.push("/settings/${dictionary.id}");
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
                              title: Text(
                                  AppLocalizations.of(context)!.titleAlias),
                              content: TextField(
                                controller: controller..text = title,
                                autofocus: true,
                                onSubmitted: (value) async {
                                  await _updateAlias(
                                      value, dictionary, context);
                                },
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () async {
                                    if (dictManager.contain(dictionary.id)) {
                                      dictManager.dicts[dictionary.id]!
                                          .setDefaultTitle();
                                      controller.text = dictManager
                                          .dicts[dictionary.id]!.title;
                                    } else {
                                      final dict = Mdict(path: dictionary.path);
                                      await dict
                                          .initOnlyMetadata(dictionary.id);
                                      controller.text = dict.title;
                                    }
                                  },
                                  child: Text(
                                      AppLocalizations.of(context)!.default_),
                                ),
                                TextButton(
                                  onPressed: () => context.pop(),
                                  child:
                                      Text(AppLocalizations.of(context)!.close),
                                ),
                                TextButton(
                                    onPressed: () async {
                                      await _updateAlias(
                                          controller.text, dictionary, context);
                                    },
                                    child: Text(
                                        AppLocalizations.of(context)!.confirm)),
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
          },
          child: CheckboxListTile(
            title: Text(title),
            value: dictManager.contain(dictionary.id),
            secondary: ReorderableDragStartListener(
                index: index,
                child:
                    IconButton(icon: Icon(Icons.reorder), onPressed: () => {})),
            onChanged: (bool? value) async {
              final model = context.read<DictManagerModel>();

              if (value == true) {
                await model.add(dictionary.path);
              } else {
                await model.close(dictionary.id);
              }

              final dictIds = [
                for (final dict in dictManager.dicts.values) dict.id
              ];
              dictManager.dictIds = dictIds;
              model.checkIsEmpty();

              await dictGroupDao.updateDictIds(dictManager.groupId, dictIds);
            },
          )),
    );
  }

  Future<void> _updateAlias(
      String value, DictionaryListData dictionary, BuildContext context) async {
    if (value.isNotEmpty) {
      if (dictManager.contain(dictionary.id)) {
        dictManager.dicts[dictionary.id]!.title = value;
      }
      await dictionaryListDao.updateAlias(dictionary.id, value);
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

class ManageDictionaries extends StatefulWidget {
  const ManageDictionaries({super.key});

  @override
  State<ManageDictionaries> createState() => ManageDictionariesState();
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
        final children = <Widget>[];

        if (snapshot.hasData) {
          int index = 0;
          final dicts = snapshot.data!;
          final dictsMap = {for (final dict in dicts) dict.id: dict};
          for (final id in dictManager.dictIds) {
            final dict = dictsMap[id]!;
            children.add(DictionaryCard(
                key: ValueKey(dict.id), dictionary: dict, index: index));
            index += 1;
          }
          for (final dict in dicts) {
            if (!dictManager.contain(dict.id)) {
              children.add(DictionaryCard(
                  key: ValueKey(dict.id), dictionary: dict, index: index));
              index += 1;
            }
          }
        }

        if (children.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context)!.empty));
        } else {
          return ReorderableListView(
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) async {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }

              final dicts =
                  await context.read<ManageDictionariesModel>().dictionaries;
              final dict = dicts.removeAt(oldIndex);
              dicts.insert(newIndex, dict);
              if (dictManager.contain(dict.id)) {
                await dictGroupDao.updateDictIds(dictManager.groupId, [
                  for (final dict in dicts)
                    if (dictManager.contain(dict.id)) dict.id
                ]);

                if (context.mounted) {
                  final model = context.read<DictManagerModel>();
                  await model.updateDictIds();
                }
              }
            },
            children: children,
          );
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
}

class ManageDictionariesState extends State<ManageDictionaries> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: BackButton(), actions: [
        if (Platform.isAndroid) UpdateButton(),
        InfoButton(),
        AddButton(),
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
      floatingActionButton: FloatingActionButton(
        heroTag: UniqueKey(),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => GroupDialog(),
          );
        },
        child: const Icon(Icons.group),
      ),
    );
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

import "dart:io";

import "package:ciyue/database/app.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/widget/loading_dialog.dart";
import "package:ciyue/widget/text_buttons.dart";
import "package:device_info_plus/device_info_plus.dart";
import "package:file_selector/file_selector.dart";
import "package:filesystem_picker/filesystem_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";
import "package:path/path.dart";
import "package:permission_handler/permission_handler.dart";

class ManageDictionaries extends StatefulWidget {
  const ManageDictionaries({super.key});

  @override
  State<ManageDictionaries> createState() => _ManageDictionariesState();
}

class _ManageDictionariesState extends State<ManageDictionaries> {
  var dictionaries = dictionaryListDao.all();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: buildReturnButton(context), actions: [
        buildSettingScanPathButton(context),
        buildRefreshButton(context),
        buildAddButton(context)
      ]),
      body: buildBody(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => _buildGroupDialog(context),
          );
        },
        child: const Icon(Icons.group),
      ),
    );
  }

  Widget _buildGroupDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Groups'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final group in dictManager.groups)
            RadioListTile(
              title: Text(group.name),
              value: group.id,
              groupValue: dictManager.groupId,
              secondary: buildGroupDeleteButton(context, group),
              onChanged: (int? groupId) async {
                if (groupId != dictManager.groupId) {
                  await dictManager.setCurrentGroup(groupId!);
                  setState(() {});
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
                    onSubmitted: (value) async {
                      if (value.isNotEmpty) {
                        await dictGroupDao.addGroup(value, []);
                        await dictManager.updateGroupList();
                        if (context.mounted) {
                          context.pop();
                        }
                      }
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text(AppLocalizations.of(context)!.close),
                    ),
                    TextButton(
                        onPressed: () async {
                          if (controller.text != "") {
                            await dictGroupDao.addGroup(controller.text, []);
                            await dictManager.updateGroupList();
                            if (context.mounted) {
                              context.pop();
                            }
                          }
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

  IconButton? buildGroupDeleteButton(
      BuildContext context, DictGroupData group) {
    if (group.name == "Default") {
      return null;
    }

    return IconButton(
      icon: const Icon(Icons.delete),
      onPressed: () async {
        if (group.id == dictManager.groupId) {
          if (group.id == dictManager.groups.last.id) {
            await dictManager.setCurrentGroup(
                dictManager.groups[dictManager.groups.length - 2].id);
          } else {
            final index =
                dictManager.groups.indexWhere((g) => g.id == group.id);
            await dictManager.setCurrentGroup(dictManager.groups[index + 1].id);
          }
        }

        await dictGroupDao.removeGroup(group.id);
        await dictManager.updateGroupList();

        if (context.mounted) context.pop();
      },
    );
  }

  IconButton buildAddButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add),
      onPressed: () async {
        String? path;

        if (Platform.isAndroid) {
          final sdkVersion =
              (await DeviceInfoPlugin().androidInfo).version.sdkInt;

          if (sdkVersion >= 30) {
            if (await Permission.manageExternalStorage.request().isDenied &&
                context.mounted) {
              showPermissionDenied(context);
              return;
            }
          } else {
            if (await Permission.storage.request().isDenied &&
                context.mounted) {
              showPermissionDenied(context);
              return;
            }
          }

          if (context.mounted) {
            path = await FilesystemPicker.open(
                context: context,
                fsType: FilesystemType.file,
                allowedExtensions: [".mdx"],
                rootDirectory: Directory("/storage/emulated/0/"));
          }
        } else {
          const XTypeGroup typeGroup = XTypeGroup(
            label: "custom",
            extensions: <String>["mdx"],
          );

          final file = await openFile(acceptedTypeGroups: [typeGroup]);
          path = file?.path;
        }

        if (path != null) {
          if (context.mounted) showLoadingDialog(context);

          late final Mdict tmpDict;
          try {
            path = setExtension(path, "");
            tmpDict = Mdict(path: path);
            if (await tmpDict.add()) {
              await tmpDict.close();
            }
          } catch (e) {
            await tmpDict.close();
            if (context.mounted) {
              final snackBar = SnackBar(
                  content: Text(AppLocalizations.of(context)!.notSupport));
              ScaffoldMessenger.of(context).showSnackBar(snackBar);
            }
          }

          setState(() {
            context.pop();
            updateDictionaries();
          });
        }
      },
    );
  }

  FutureBuilder<List<DictionaryListData>> buildBody(BuildContext context) {
    return FutureBuilder(
      future: dictionaries,
      builder: (BuildContext context,
          AsyncSnapshot<List<DictionaryListData>> snapshot) {
        final children = <Widget>[];

        if (snapshot.hasData) {
          int index = 0;
          final dicts = snapshot.data!;
          final dictsMap = {for (final dict in dicts) dict.id: dict};
          for (final id in dictManager.dictIds) {
            children.add(buildDictionaryCard(context, dictsMap[id]!, index));
            index += 1;
          }
          for (final dict in dicts) {
            if (!dictManager.contain(dict.id)) {
              children.add(buildDictionaryCard(context, dict, index));
              index += 1;
            }
          }
        }

        if (children.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context)!.empty));
        } else {
          return ReorderableListView(
            onReorder: (oldIndex, newIndex) async {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }

              final dicts = await dictionaries;
              final dict = dicts.removeAt(oldIndex);
              dicts.insert(newIndex, dict);
              if (dictManager.contain(dict.id)) {
                await dictGroupDao.updateDictIds(dictManager.groupId, [
                  for (final dict in dicts)
                    if (dictManager.contain(dict.id)) dict.id
                ]);
                await dictManager.updateDictIds();
              }

              setState(() {});
            },
            children: children,
          );
        }
      },
    );
  }

  Card buildDictionaryCard(
      BuildContext context, DictionaryListData dictionary, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: ValueKey(dictionary.id),
      elevation: 0,
      color: colorScheme.onInverseSurface,
      child: GestureDetector(
          onLongPress: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return SimpleDialog(
                  title: Text(basename(dictionary.path)),
                  children: <Widget>[
                    SimpleDialogOption(
                      onPressed: () async {
                        if (dictManager.contain(dictionary.id)) {
                          dictManager.remove(dictionary.id);

                          final dictIds = [
                            for (final dict in dictManager.dicts.values) dict.id
                          ];

                          dictGroupDao.updateDictIds(
                              dictManager.groupId, dictIds);
                        } else {
                          final tmpDict = Mdict(path: dictionary.path);
                          await tmpDict.init();
                          await tmpDict.removeDictionary();
                          await tmpDict.close();
                        }

                        setState(() {
                          updateDictionaries();
                        });

                        if (context.mounted) context.pop();
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
                        context.push("/settings/dictionary/${dictionary.id}");
                      },
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text(AppLocalizations.of(context)!.settings),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          child: CheckboxListTile(
            title: Text(basename(dictionary.path)),
            value: dictManager.contain(dictionary.id),
            secondary: ReorderableDragStartListener(
                index: index,
                child:
                    IconButton(icon: Icon(Icons.reorder), onPressed: () => {})),
            onChanged: (bool? value) async {
              if (value == true) {
                await dictManager.add(dictionary.path);
              } else {
                await dictManager.close(dictionary.id);
              }
              await dictGroupDao.updateDictIds(dictManager.groupId,
                  [for (final dict in dictManager.dicts.values) dict.id]);
              await dictManager.updateDictIds();

              setState(() {});
            },
          )),
    );
  }

  IconButton buildRefreshButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: () async {
        final paths = prefs.getStringList("scanPaths");
        if (paths != null) {
          showLoadingDialog(context);

          try {
            await _scanDictionaries(paths);
          } finally {
            setState(() {
              context.pop();
              updateDictionaries();
            });
          }
        }
      },
    );
  }

  IconButton buildReturnButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        context.pop();
      },
    );
  }

  IconButton buildSettingScanPathButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.folder),
      onPressed: () async {
        final paths = prefs.getStringList("scanPaths") ?? [];

        if (paths.isEmpty) {
          await _addScanPath(context);
        } else {
          final listTiles = <Widget>[];
          for (final path in paths) {
            listTiles.add(ListTile(
              title: Text(path.replaceFirst("/storage/emulated/0/", "")),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () async {
                  await _removeScanPath(path);

                  if (context.mounted) context.pop();
                },
              ),
            ));
          }

          await showDialog(
              context: context,
              builder: (BuildContext _) => AlertDialog(
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: listTiles,
                      ),
                    ),
                    actions: [
                      TextCloseButton(),
                      TextButton(
                        child: Text(AppLocalizations.of(context)!.add),
                        onPressed: () async {
                          await _addScanPath(context);
                          if (context.mounted) context.pop();
                        },
                      ),
                    ],
                  ));
        }
      },
    );
  }

  void showPermissionDenied(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context)!.permissionDenied),
      action: SnackBarAction(
          label: AppLocalizations.of(context)!.close, onPressed: () {}),
    ));
  }

  void updateDictionaries() {
    dictionaries = dictionaryListDao.all();
  }

  Future<void> _addScanPath(BuildContext context) async {
    final path = await getDirectoryPath();
    if (path == null) {
      return;
    }

    final paths = prefs.getStringList("scanPaths") ?? [];
    if (paths.contains(path)) {
      return;
    }

    if (context.mounted) showLoadingDialog(context);

    try {
      await _scanDictionaries(paths);
    } finally {
      paths.add(path);
      prefs.setStringList("scanPaths", paths);

      setState(() {
        context.pop();
        updateDictionaries();
      });
    }
  }

  Future<void> _removeScanPath(String path) async {
    final paths = prefs.getStringList("scanPaths")!;
    paths.remove(path);
    prefs.setStringList("scanPaths", paths);
  }

  Future<void> _scanDictionaries(List<String> paths) async {
    for (final path in paths) {
      final dir = Directory(path);
      final files = await dir.list().toList();

      for (final file in files) {
        if (extension(file.path) == ".mdx") {
          final tempDict = Mdict(path: setExtension(file.path, ""));
          await tempDict.add();
          await tempDict.close();
        }
      }
    }
  }
}

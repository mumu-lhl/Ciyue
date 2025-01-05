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
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder(
      future: dictionaries,
      builder: (BuildContext context,
          AsyncSnapshot<List<DictionaryListData>> snapshot) {
        final children = <Widget>[];

        if (snapshot.hasData) {
          final dictionaries = snapshot.data!;
          for (final dictionary in dictionaries) {
            children.add(buildDictionaryCard(context, colorScheme, dictionary));
          }
        }

        if (children.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context)!.empty));
        } else {
          return ListView(children: children);
        }
      },
    );
  }

  Card buildDictionaryCard(BuildContext context, ColorScheme colorScheme,
      DictionaryListData dictionary) {
    return Card(
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
            onChanged: (bool? value) async {
              if (value == true) {
                await dictManager.add(dictionary.path);
              } else {
                await dictManager.close(dictionary.id);
              }
              dictGroupDao.updateDictIds(dictManager.groupId,
                  [for (final dict in dictManager.dicts.values) dict.id]);

              setState(() {});
            },
          ),
        ));
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

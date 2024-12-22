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
  var dictionaries = mainDatabase.all();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: buildReturnButton(context), actions: [
        buildSettingScanPathButton(context),
        buildRefreshButton(context),
        buildAddButton(context)
      ]),
      body: buildBody(context),
      floatingActionButton: buildFloatingActionButton(),
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
            tmpDict = Mdict(path: setExtension(path, ""));
            if (await tmpDict.add()) {
              if (dict != null) {
                await dict!.close();
              }
              dict = tmpDict;
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
            children.add(
                buildDictionaryCard(colorScheme, dictionary, dictionaries));
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

  Card buildDictionaryCard(ColorScheme colorScheme,
      DictionaryListData dictionary, List<DictionaryListData> dictionaries) {
    return Card(
        elevation: 0,
        color: colorScheme.onInverseSurface,
        child: RadioListTile(
            title: Text(basename(dictionary.path)),
            value: dictionary.id,
            groupValue: dict!.id,
            onChanged: (int? id) async {
              await _changeDictionary(dictionary.path);
              setState(() {});
            },
            secondary: buildRemoveButton(dictionary, dictionaries)));
  }

  FutureBuilder<List<DictionaryListData>> buildFloatingActionButton() {
    return FutureBuilder(
      future: dictionaries,
      builder: (BuildContext context,
          AsyncSnapshot<List<DictionaryListData>> snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final settingsButton = FloatingActionButton.small(
            elevation: 0,
            highlightElevation: 0,
            child: Icon(Icons.settings),
            onPressed: () {
              context.push("/settings/dictionary");
            },
          );
          final infoButton = FloatingActionButton.small(
            elevation: 0,
            highlightElevation: 0,
            child: Icon(Icons.info),
            onPressed: () {
              context.push("/description");
            },
          );
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [settingsButton, infoButton],
          );
        }

        return Text("");
      },
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

  IconButton buildRemoveButton(
      DictionaryListData dictionary, List<DictionaryListData> dictionaries) {
    return IconButton(
      icon: const Icon(Icons.delete),
      onPressed: () async {
        if (dictionary.id == dict!.id) {
          dict!.removeDictionary();

          if (dictionaries.length == 1) {
            dict = null;
            await prefs.remove("currentDictionaryPath");
          } else {
            final index = dictionaries.indexOf(dictionary);
            if (index + 1 == dictionaries.length) {
              await _changeDictionary(dictionaries[index - 1].path);
            } else {
              await _changeDictionary(dictionaries.last.path);
            }
          }
        } else {
          final tmpDict = Mdict(path: dictionary.path);
          await tmpDict.init();
          await tmpDict.removeDictionary();
          await tmpDict.close();
        }

        setState(() {
          updateDictionaries();
        });
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
    dictionaries = mainDatabase.all();
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

  Future<void> _changeDictionary(String path) async {
    await prefs.setString("currentDictionaryPath", path);
    await dict!.close();
    dict = Mdict(path: path);
    await dict!.init();
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
          dict = Mdict(path: setExtension(file.path, ""));
          await dict!.add();
        }
      }
    }
  }
}

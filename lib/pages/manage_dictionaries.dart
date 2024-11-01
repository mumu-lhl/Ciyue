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

const XTypeGroup typeGroup = XTypeGroup(
  label: "custom",
  extensions: <String>["mdx"],
);

void showPermissionDenied(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(AppLocalizations.of(context)!.permissionDenied),
    action: SnackBarAction(
        label: AppLocalizations.of(context)!.close, onPressed: () {}),
  ));
}

class ManageDictionaries extends StatefulWidget {
  const ManageDictionaries({super.key});

  @override
  State<ManageDictionaries> createState() => _ManageDictionariesState();
}

class _ManageDictionariesState extends State<ManageDictionaries> {
  var dictionaries = dictionaryList.all();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final body = FutureBuilder(
      future: dictionaries,
      builder: (BuildContext context,
          AsyncSnapshot<List<DictionaryListData>> snapshot) {
        final children = <Widget>[];

        if (snapshot.hasData) {
          for (final dictionary in snapshot.data!) {
            children.add(Card(
                elevation: 0,
                color: colorScheme.onInverseSurface,
                child: RadioListTile(
                    title: Text(basename(dictionary.path)),
                    value: dictionary.id,
                    groupValue: dict.id,
                    onChanged: (int? id) {
                      setState(() {
                        dict.id = id;
                        dict.changeDictionary(dictionary.id, dictionary.path);
                      });
                    },
                    secondary: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await dict.removeDictionary(dictionary.path);

                        setState(() {
                          updateDictionaries();
                        });
                      },
                    ))));
          }
        }

        if (children.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context)!.empty));
        } else {
          return ListView(children: children);
        }
      },
    );

    final addButton = IconButton(
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
          final file = await openFile(acceptedTypeGroups: [typeGroup]);
          path = file?.path;
        }

        if (path != null) {
          if (context.mounted) showLoadingDialog(context);

          try {
            await dict.addDictionary(path);
          } catch (e) {
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

    final settingScanPathButton = IconButton(
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
              builder: (BuildContext _) => SimpleDialog(
                    children: [
                      ...listTiles,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextCloseButton(),
                          TextButton(
                            child: Text(AppLocalizations.of(context)!.add),
                            onPressed: () async {
                              await _addScanPath(context);
                              if (context.mounted) context.pop();
                            },
                          )
                        ],
                      ),
                    ],
                  ));
        }
      },
    );

    final refreshButton = IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: () async {
        final paths = prefs.getStringList("scanPaths");
        if (paths != null) {
          showLoadingDialog(context);

          for (final path in paths) {
            await dict.scanDictionaries(path);
          }

          setState(() {
            context.pop();
            updateDictionaries();
          });
        }
      },
    );

    final returnButton = IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        context.pop();
      },
    );

    final appBar = AppBar(
        leading: returnButton,
        actions: [settingScanPathButton, refreshButton, addButton]);

    Widget? floatingActionButton;
    floatingActionButton = FutureBuilder(
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
              context.push("/word", extra: {
                "content": dict.reader!.header["Description"]!,
                "word": "",
                "description": "1",
              });
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

    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  void updateDictionaries() {
    dictionaries = dictionaryList.all();
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

    paths.add(path);
    prefs.setStringList("scanPaths", paths);

    for (final path in paths) {
      await dict.scanDictionaries(path);
    }

    setState(() {
      context.pop();
      updateDictionaries();
    });
  }

  Future<void> _removeScanPath(String path) async {
    final paths = prefs.getStringList("scanPaths")!;
    paths.remove(path);
    prefs.setStringList("scanPaths", paths);
  }
}

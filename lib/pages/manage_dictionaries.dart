import "dart:io";

import "package:device_info_plus/device_info_plus.dart";
import "package:filesystem_picker/filesystem_picker.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:path/path.dart";
import "package:permission_handler/permission_handler.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";

import "../database.dart";
import "../dictionary.dart";
import "../main.dart";

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
  var _loading = false;

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = FutureBuilder(
        future: dictionaries,
        builder: (BuildContext context,
            AsyncSnapshot<List<DictionaryListData>> snapshot) {
          final children = <Widget>[];

          if (snapshot.hasData) {
            for (final dictionary in snapshot.data!) {
              children.add(Card(
                  child: RadioListTile(
                      title: Text(basename(dictionary.path)),
                      value: dictionary.id,
                      groupValue: currentDictionaryId,
                      onChanged: (int? id) {
                        setState(() {
                          currentDictionaryId = id;
                          changeDictionary(dictionary.id, dictionary.path);
                        });
                      },
                      secondary: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await removeDictionary(dictionary.path);
                          setState(() {
                            dictionaries = dictionaryList.all();
                          });
                        },
                      ))));
            }
          }

          return ListView(children: children);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.pop();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final sdkVersion =
                    (await DeviceInfoPlugin().androidInfo).version.sdkInt;

                if (sdkVersion >= 33) {
                  if (await Permission.manageExternalStorage
                          .request()
                          .isDenied &&
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
                  final path = await FilesystemPicker.open(
                      context: context,
                      fsType: FilesystemType.file,
                      allowedExtensions: [".mdx"],
                      rootDirectory: Directory("/storage/emulated/0/"));
                  if (path != null) {
                    setState(() {
                      _loading = true;
                    });

                    await addDictionary(path.substring(0, path.length - 4));

                    setState(() {
                      _loading = false;
                      dictionaries = dictionaryList.all();
                    });
                  }
                }
              },
            )
          ]),
      body: body,
    );
  }
}

import "dart:io";

import "package:device_info_plus/device_info_plus.dart";
import "package:file_selector/file_selector.dart";
import "package:filesystem_picker/filesystem_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";
import "package:path/path.dart";
import "package:permission_handler/permission_handler.dart";

import "../database/app.dart";
import "../dictionary.dart";
import "../main.dart";

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
          setState(() {
            _loading = true;
          });

          try {
            await addDictionary(path.substring(0, path.length - 4));
          } catch (e) {
            if (context.mounted) {
              final snackBar = SnackBar(
                  content: Text(AppLocalizations.of(context)!.notSupport));
              ScaffoldMessenger.of(context).showSnackBar(snackBar);
            }
          }

          setState(() {
            _loading = false;
            dictionaries = dictionaryList.all();
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
    final appBar = AppBar(leading: returnButton, actions: [addButton]);

    Widget? floatingActionButton;
    floatingActionButton = FutureBuilder(
      future: dictionaries,
      builder: (BuildContext context,
          AsyncSnapshot<List<DictionaryListData>> snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty && !_loading) {
          return FloatingActionButton(
            child: Icon(Icons.info),
            onPressed: () {
              context.push("/word", extra: {
                "content": dictReader!.header["Description"]!,
                "word": "",
                "description": "1",
              });
            },
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
}

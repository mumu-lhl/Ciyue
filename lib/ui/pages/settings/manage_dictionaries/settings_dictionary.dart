import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:file_selector/file_selector.dart";
import "package:flutter/material.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:go_router/go_router.dart";

class SettingsDictionaryPage extends StatelessWidget {
  final int dictId;
  const SettingsDictionaryPage({super.key, required this.dictId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(leading: BackButton(
          onPressed: () {
            context.pop();
          },
        )),
        body: _Body(dictId: dictId));
  }
}

class _Body extends StatefulWidget {
  final int dictId;
  const _Body({required this.dictId});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  void customFont(String? path) async {
    if (dictManager.dicts.containsKey(widget.dictId)) {
      await dictManager.dicts[widget.dictId]!.customFont(path);
    } else {
      final dict = Mdict(path: await dictionaryListDao.getPath(widget.dictId));
      await dict.init();
      await dict.customFont(path);
      await dict.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget? fontPathSubtitle;
    Widget? removeButton;
    if (dictManager.dicts.values.first.fontName != null) {
      fontPathSubtitle = Text(dictManager.dicts.values.first.fontName!);
      removeButton = IconButton(
        icon: Icon(Icons.delete_sweep),
        onPressed: () {
          setState(() async {
            customFont(null);
          });
        },
      );
    }

    return ListView(
      children: [
        ListTile(
          leading: Icon(Icons.font_download),
          title: Text(AppLocalizations.of(context)!.customFont),
          subtitle: fontPathSubtitle,
          trailing: removeButton,
          onTap: () async {
            final typeGroup =
                XTypeGroup(extensions: ["ttf", "otf", "woff", "woff2"]);
            final xFile = await openFile(acceptedTypeGroups: [typeGroup]);
            if (xFile == null) {
              return;
            }

            setState(() async {
              customFont(xFile.path);
            });
          },
        )
      ],
    );
  }
}

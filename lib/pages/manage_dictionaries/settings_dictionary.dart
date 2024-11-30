import "package:ciyue/dictionary.dart";
import "package:file_selector/file_selector.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

class SettingsDictionary extends StatelessWidget {
  const SettingsDictionary({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(leading: BackButton(
          onPressed: () {
            context.pop();
          },
        )),
        body: _Body());
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  @override
  Widget build(BuildContext context) {
    Widget? fontPathSubtitle;
    Widget? removeButton;
    if (dict.fontName != null) {
      fontPathSubtitle = Text(dict.fontName!);
      removeButton = IconButton(
        icon: Icon(Icons.delete_sweep),
        onPressed: () {
          setState(() {
            dict.customFont(null);
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

            setState(() {
              dict.customFont(xFile.path);
            });
          },
        )
      ],
    );
  }
}

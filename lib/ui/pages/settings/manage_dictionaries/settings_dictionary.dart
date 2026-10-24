import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:file_selector/file_selector.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:go_router/go_router.dart";

class SettingsDictionaryPage extends StatelessWidget {
  final int dictId;
  const SettingsDictionaryPage({super.key, required this.dictId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: _Body(dictId: dictId),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  final int dictId;
  const _Body({required this.dictId});

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  void customFont(String? path) async {
    final dict = dictManager.dicts[widget.dictId];
    if (dict is Mdict) {
      await dict.customFont(path);
    } else {
      // Updating the font only touches the database; do not initialize and
      // scan an inactive dictionary just for this setting. (Only MDict
      // dictionaries apply a custom font when loaded.)
      await dictionaryListDao.updateFont(widget.dictId, path);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when dictionary loading finishes, so this page — reachable
    // from the manage-dictionaries page while dictionaries are still
    // loading — does not keep showing the pre-load state.
    ref.watch(dictManagerModelProvider.select((model) => model.state));
    Widget? fontPathSubtitle;
    Widget? removeButton;
    // dicts is empty until the background group load finishes; .first
    // would throw in that window.
    final loadedDicts = dictManager.dicts.values;
    final firstDict = loadedDicts.isEmpty ? null : loadedDicts.first;
    if (firstDict is Mdict && firstDict.fontName != null) {
      fontPathSubtitle = Text(firstDict.fontName!);
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
            final typeGroup = XTypeGroup(
              extensions: ["ttf", "otf", "woff", "woff2"],
            );
            final xFile = await openFile(acceptedTypeGroups: [typeGroup]);
            if (xFile == null) {
              return;
            }

            setState(() async {
              customFont(xFile.path);
            });
          },
        ),
      ],
    );
  }
}

import 'package:ciyue/main.dart';
import 'package:ciyue/settings.dart';
import 'package:flutter/material.dart';
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import 'package:go_router/go_router.dart';

class AutoExport extends StatelessWidget {
  const AutoExport({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.pop()),
          title: const Text('Auto Export'),
        ),
        body: ListView(
          children: [
            Enable(),
            FileName(),
            ExportDirectory(),
          ],
        ));
  }
}

class Enable extends StatefulWidget {
  const Enable({
    super.key,
  });

  @override
  State<Enable> createState() => _EnableState();
}

class ExportDirectory extends StatefulWidget {
  const ExportDirectory({super.key});

  @override
  State<ExportDirectory> createState() => _ExportDirectoryState();
}

class FileName extends StatefulWidget {
  const FileName({
    super.key,
  });

  @override
  State<FileName> createState() => _FileNameState();
}

class _EnableState extends State<Enable> {
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(AppLocalizations.of(context)!.autoExport),
      secondary: Icon(Icons.backup),
      value: settings.autoExport,
      onChanged: (bool value) {
        settings.autoExport = value;
        prefs.setBool("autoExport", value);
        setState(() {});
      },
    );
  }
}

class _ExportDirectoryState extends State<ExportDirectory> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.exportDirectory),
      subtitle: settings.exportDirectory == null
          ? null
          : Text(settings.exportDirectory!),
      leading: Icon(Icons.folder),
      onTap: () async {
        platform.invokeMethod('getDirectory');
      },
    );
  }
}

class _FileNameState extends State<FileName> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.exportFileName),
      subtitle: Text(settings.exportFileName),
      leading: Icon(Icons.file_present),
      onTap: () async {
        final controller = TextEditingController(text: settings.exportFileName);
        final fileName = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.exportFileName),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "ciyue",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.close),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(AppLocalizations.of(context)!.confirm),
              ),
            ],
          ),
        );
        if (fileName != null) {
          setState(() {
            settings.exportFileName = fileName;
            prefs.setString('exportFileName', fileName);
          });
        }
      },
    );
  }
}

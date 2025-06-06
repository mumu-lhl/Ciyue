import "dart:convert";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/main.dart";
import "package:ciyue/services/backup.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:file_selector/file_selector.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

class AutoExport extends StatelessWidget {
  const AutoExport({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: Icon(Icons.backup),
        title: Text(AppLocalizations.of(context)!.autoExport),
        trailing: Icon(Icons.arrow_forward),
        onTap: () => context.push("/settings/autoExport"));
  }
}

class BackupSettingsPage extends StatelessWidget {
  const BackupSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.export),
      ),
      body: ListView(
        children: [
          const AutoExport(),
          const Export(),
          const Import(),
          const LegacyImport(),
        ],
      ),
    );
  }
}

class Export extends StatelessWidget {
  const Export({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.file_upload),
      title: Text(AppLocalizations.of(context)!.export),
      onTap: () => Backup.export(false),
    );
  }
}

class Import extends StatelessWidget {
  const Import({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.file_download),
      title: Text(AppLocalizations.of(context)!.import),
      onTap: () => Backup.import(),
    );
  }
}

class LegacyImport extends StatelessWidget {
  const LegacyImport({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.file_download),
      title: Text(AppLocalizations.of(context)!.legacyImport),
      onTap: () async {
        const XTypeGroup typeGroup = XTypeGroup(
          label: "json",
          extensions: <String>["json"],
        );
        final xFile = await openFile(acceptedTypeGroups: [typeGroup]);
        if (xFile == null) {
          return;
        }

        final content = (await xFile.readAsString()).split("\n"),
            wordsJson = jsonDecode(content[0]),
            tagsJson = jsonDecode(content[1]);

        final wordsData = <WordbookData>[];
        for (final i in wordsJson) {
          final json = Map<String, dynamic>.from(i);
          if (!json.containsKey("createdAt")) {
            json["createdAt"] = DateTime.now().toIso8601String();
          }
          wordsData.add(WordbookData.fromJson(json));
        }

        final tagsData = <WordbookTag>[];
        for (final i in tagsJson) {
          tagsData.add(WordbookTag.fromJson(i));
        }

        await wordbookDao.addAllWords(wordsData);
        await wordbookTagsDao.addAllTags(tagsData);
      },
    );
  }
}

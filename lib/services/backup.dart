import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/backup/backup.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/repositories/settings.dart";
import "package:file_selector/file_selector.dart";
import "package:path/path.dart";

class Backup {
  static const version = 1;

  static Future<void> export(bool autoExport) async {
    final words = await wordbookDao.getAllWords(),
        tags = await wordbookTagsDao.getAllTags();

    if (words.isNotEmpty) {
      final backupData = BackupData(
        version: version,
        wordbookWords: words,
        wordbookTags: tags,
      );

      if (autoExport) {
        if (Platform.isAndroid) {
          final fileName = setExtension(settings.exportFileName, ".json");
          final path = join(settings.exportDirectory!, fileName);

          await PlatformMethod.writeFile({
            "path": path,
            "directory": settings.exportDirectory,
            "filename": fileName,
            "content": backupData.toJson(),
          });
        } else {
          final file = File(join(settings.exportPath!));
          await file.writeAsString(backupData.toJson());
        }

        return;
      }

      if (Platform.isAndroid) {
        await PlatformMethod.createFile(backupData.toJson());
      } else {
        final result = await getSaveLocation(suggestedName: "ciyue.json");
        if (result != null) {
          final file = File(result.path);
          await file.writeAsString(backupData.toJson());
        }
      }
    }
  }

  static Future<void> import() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: "json",
      extensions: <String>["json"],
    );
    final xFile = await openFile(acceptedTypeGroups: [typeGroup]);
    if (xFile == null) {
      return;
    }

    final Map<String, dynamic> content = jsonDecode(await xFile.readAsString());
    final backupData = BackupData.fromJson(content);

    await wordbookDao.addAllWords(backupData.wordbookWords);
    await wordbookTagsDao.addAllTags(backupData.wordbookTags);
  }
}

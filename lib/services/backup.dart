import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/backup/backup.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:file_selector/file_selector.dart";
import "package:path/path.dart";
import "package:provider/provider.dart";

abstract class BackupFileHandler {
  bool get isAndroid;
  Future<void> writeAutoExportAndroid(
      String directory, String fileName, String content);
  Future<void> writeAutoExportDesktop(String path, String content);
  Future<void> writeManualExportAndroid(String content);
  Future<void> writeManualExportDesktop(String content);
  Future<String?> readImportFile();
}

class DefaultBackupFileHandler implements BackupFileHandler {
  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  Future<void> writeAutoExportAndroid(
      String directory, String fileName, String content) async {
    final path = join(directory, fileName);
    await PlatformMethod.writeFile({
      "path": path,
      "directory": directory,
      "filename": fileName,
      "content": content,
    });
  }

  @override
  Future<void> writeAutoExportDesktop(String path, String content) async {
    final file = File(join(path));
    await file.writeAsString(content);
  }

  @override
  Future<void> writeManualExportAndroid(String content) async {
    await PlatformMethod.createFile(content);
  }

  @override
  Future<void> writeManualExportDesktop(String content) async {
    final result = await getSaveLocation(suggestedName: "ciyue.json");
    if (result != null) {
      final file = File(result.path);
      await file.writeAsString(content);
    }
  }

  @override
  Future<String?> readImportFile() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: "json",
      extensions: <String>["json"],
    );
    final xFile = await openFile(acceptedTypeGroups: [typeGroup]);
    if (xFile == null) {
      return null;
    }
    return await xFile.readAsString();
  }
}

class BackupService {
  final WordbookDao wordbookDao;
  final WordbookTagsDao wordbookTagsDao;
  final HistoryDao historyDao;
  final BackupFileHandler fileHandler;
  final WordbookModel? _wordbookModel;

  BackupService({
    required this.wordbookDao,
    required this.wordbookTagsDao,
    required this.historyDao,
    required this.fileHandler,
    WordbookModel? wordbookModel,
  }) : _wordbookModel = wordbookModel;

  Future<void> export({
    required bool autoExport,
    required String exportFileName,
    String? exportDirectory,
    String? exportPath,
  }) async {
    final words = await wordbookDao.getAllWords(),
        tags = await wordbookTagsDao.getAllTags(),
        history = await historyDao.getAllHistory();

    if (words.isNotEmpty || history.isNotEmpty) {
      final backupData = BackupData(
        version: Backup.version,
        wordbookWords: words,
        wordbookTags: tags,
        history: history.map((e) => e.word).toList(),
      );
      final jsonContent = backupData.toJson();

      if (autoExport) {
        if (fileHandler.isAndroid) {
          final fileName = setExtension(exportFileName, ".json");
          if (exportDirectory != null) {
            await fileHandler.writeAutoExportAndroid(
                exportDirectory, fileName, jsonContent);
          }
        } else {
          if (exportPath != null) {
            await fileHandler.writeAutoExportDesktop(exportPath, jsonContent);
          }
        }
        return;
      }

      if (fileHandler.isAndroid) {
        await fileHandler.writeManualExportAndroid(jsonContent);
      } else {
        await fileHandler.writeManualExportDesktop(jsonContent);
      }
    }
  }

  Future<void> import() async {
    final contentString = await fileHandler.readImportFile();
    if (contentString == null) {
      return;
    }

    final Map<String, dynamic> content = jsonDecode(contentString);
    final backupData = BackupData.fromJson(content);

    final wordbookModel = _wordbookModel ??
        Provider.of<WordbookModel>(navigatorKey.currentContext!, listen: false);

    await wordbookModel.addAllWords(backupData.wordbookWords);
    await wordbookTagsDao.addAllTags(backupData.wordbookTags);

    // Import history: add from oldest to newest to preserve order (since addHistory adds to top)
    for (final word in backupData.history.reversed) {
      await historyDao.addHistory(word);
    }
  }
}

class Backup {
  static const version = 1;

  static Future<void> export(bool autoExport) async {
    final service = BackupService(
      wordbookDao: wordbookDao,
      wordbookTagsDao: wordbookTagsDao,
      historyDao: historyDao,
      fileHandler: DefaultBackupFileHandler(),
    );
    await service.export(
      autoExport: autoExport,
      exportFileName: settings.exportFileName,
      exportDirectory: settings.exportDirectory,
      exportPath: settings.exportPath,
    );
  }

  static Future<void> import() async {
    final service = BackupService(
      wordbookDao: wordbookDao,
      wordbookTagsDao: wordbookTagsDao,
      historyDao: historyDao,
      fileHandler: DefaultBackupFileHandler(),
    );
    await service.import();
  }
}

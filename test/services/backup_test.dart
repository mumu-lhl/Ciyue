import "dart:convert";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/services/backup.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";

import "backup_test.mocks.dart";

@GenerateMocks([
  WordbookDao,
  WordbookTagsDao,
  HistoryDao,
  WritingCheckHistoryDao,
  TranslateHistoryDao,
  BackupFileHandler,
  WordbookModel
])
void main() {
  late MockWordbookDao mockWordbookDao;
  late MockWordbookTagsDao mockWordbookTagsDao;
  late MockHistoryDao mockHistoryDao;
  late MockWritingCheckHistoryDao mockWritingCheckHistoryDao;
  late MockTranslateHistoryDao mockTranslateHistoryDao;
  late MockBackupFileHandler mockFileHandler;
  late MockWordbookModel mockWordbookModel;
  late BackupService backupService;

  setUp(() {
    mockWordbookDao = MockWordbookDao();
    mockWordbookTagsDao = MockWordbookTagsDao();
    mockHistoryDao = MockHistoryDao();
    mockWritingCheckHistoryDao = MockWritingCheckHistoryDao();
    mockTranslateHistoryDao = MockTranslateHistoryDao();
    mockFileHandler = MockBackupFileHandler();
    mockWordbookModel = MockWordbookModel();

    backupService = BackupService(
      wordbookDao: mockWordbookDao,
      wordbookTagsDao: mockWordbookTagsDao,
      historyDao: mockHistoryDao,
      writingCheckHistoryDao: mockWritingCheckHistoryDao,
      translateHistoryDao: mockTranslateHistoryDao,
      fileHandler: mockFileHandler,
      wordbookModel: mockWordbookModel,
    );
  });

  group("BackupService Export", () {
    final words = [
      WordbookData(
        createdAt: DateTime.now(),
        tag: 1,
        word: "test",
      )
    ];
    final tags = [const WordbookTag(id: 1, tag: "tag1")];
    final history = [const HistoryData(id: 1, word: "history1")];
    final writingCheckHistory = [
      WritingCheckHistoryData(
        id: 1,
        inputText: "input",
        outputText: "output",
        createdAt: DateTime.now(),
      )
    ];
    final translateHistory = [
      TranslateHistoryData(
        id: 1,
        inputText: "input",
        createdAt: DateTime.now(),
      )
    ];

    test("should do nothing if no words or history to export", () async {
      when(mockWordbookDao.getAllWords()).thenAnswer((_) async => []);
      when(mockWordbookTagsDao.getAllTags()).thenAnswer((_) async => []);
      when(mockHistoryDao.getAllHistory()).thenAnswer((_) async => []);
      when(mockWritingCheckHistoryDao.getAllHistory())
          .thenAnswer((_) async => []);
      when(mockTranslateHistoryDao.getAllHistory()).thenAnswer((_) async => []);

      await backupService.export(
        autoExport: false,
        exportFileName: "test",
      );

      verify(mockWordbookDao.getAllWords()).called(1);
      verify(mockHistoryDao.getAllHistory()).called(1);
      verifyNever(mockFileHandler.writeManualExportAndroid(any));
      verifyNever(mockFileHandler.writeManualExportDesktop(any));
    });

    test("should export manually on Android", () async {
      when(mockWordbookDao.getAllWords()).thenAnswer((_) async => words);
      when(mockWordbookTagsDao.getAllTags()).thenAnswer((_) async => tags);
      when(mockHistoryDao.getAllHistory()).thenAnswer((_) async => history);
      when(mockWritingCheckHistoryDao.getAllHistory())
          .thenAnswer((_) async => writingCheckHistory);
      when(mockTranslateHistoryDao.getAllHistory())
          .thenAnswer((_) async => translateHistory);
      when(mockFileHandler.isAndroid).thenReturn(true);
      when(mockFileHandler.writeManualExportAndroid(any))
          .thenAnswer((_) async {});

      await backupService.export(
        autoExport: false,
        exportFileName: "test",
      );

      verify(mockFileHandler.writeManualExportAndroid(any)).called(1);
    });

    test("should export manually on Desktop", () async {
      when(mockWordbookDao.getAllWords()).thenAnswer((_) async => words);
      when(mockWordbookTagsDao.getAllTags()).thenAnswer((_) async => tags);
      when(mockHistoryDao.getAllHistory()).thenAnswer((_) async => history);
      when(mockWritingCheckHistoryDao.getAllHistory())
          .thenAnswer((_) async => writingCheckHistory);
      when(mockTranslateHistoryDao.getAllHistory())
          .thenAnswer((_) async => translateHistory);
      when(mockFileHandler.isAndroid).thenReturn(false);
      when(mockFileHandler.writeManualExportDesktop(any))
          .thenAnswer((_) async {});

      await backupService.export(
        autoExport: false,
        exportFileName: "test",
      );

      verify(mockFileHandler.writeManualExportDesktop(any)).called(1);
    });

    test("should auto export on Android", () async {
      when(mockWordbookDao.getAllWords()).thenAnswer((_) async => words);
      when(mockWordbookTagsDao.getAllTags()).thenAnswer((_) async => tags);
      when(mockHistoryDao.getAllHistory()).thenAnswer((_) async => history);
      when(mockWritingCheckHistoryDao.getAllHistory())
          .thenAnswer((_) async => writingCheckHistory);
      when(mockTranslateHistoryDao.getAllHistory())
          .thenAnswer((_) async => translateHistory);
      when(mockFileHandler.isAndroid).thenReturn(true);
      when(mockFileHandler.writeAutoExportAndroid(any, any, any))
          .thenAnswer((_) async {});

      await backupService.export(
        autoExport: true,
        exportFileName: "test",
        exportDirectory: "/dir",
      );

      verify(mockFileHandler.writeAutoExportAndroid("/dir", "test.json", any))
          .called(1);
    });

    test("should auto export on Desktop", () async {
      when(mockWordbookDao.getAllWords()).thenAnswer((_) async => words);
      when(mockWordbookTagsDao.getAllTags()).thenAnswer((_) async => tags);
      when(mockHistoryDao.getAllHistory()).thenAnswer((_) async => history);
      when(mockWritingCheckHistoryDao.getAllHistory())
          .thenAnswer((_) async => writingCheckHistory);
      when(mockTranslateHistoryDao.getAllHistory())
          .thenAnswer((_) async => translateHistory);
      when(mockFileHandler.isAndroid).thenReturn(false);
      when(mockFileHandler.writeAutoExportDesktop(any, any))
          .thenAnswer((_) async {});

      await backupService.export(
        autoExport: true,
        exportFileName: "test",
        exportPath: "/path/test.json",
      );

      verify(mockFileHandler.writeAutoExportDesktop("/path/test.json", any))
          .called(1);
    });
  });

  group("BackupService Import", () {
    test("should import data correctly", () async {
      final jsonContent = jsonEncode({
        "version": 1,
        "wordbookWords": [],
        "wordbookTags": [],
        "history": ["history1", "history2"],
        "writingCheckHistory": [],
        "translateHistory": []
      });

      when(mockFileHandler.readImportFile())
          .thenAnswer((_) async => jsonContent);
      when(mockWordbookModel.addAllWords(any)).thenAnswer((_) async {});
      when(mockWordbookTagsDao.addAllTags(any)).thenAnswer((_) async {});
      when(mockHistoryDao.addHistory(any)).thenAnswer((_) async => 1);
      when(mockWritingCheckHistoryDao.addAllHistory(any))
          .thenAnswer((_) async {});
      when(mockTranslateHistoryDao.addAllHistory(any)).thenAnswer((_) async {});

      await backupService.import();

      verify(mockWordbookModel.addAllWords(any)).called(1);
      verify(mockWordbookTagsDao.addAllTags(any)).called(1);
      // History should be added in reverse order: history2 then history1
      verify(mockHistoryDao.addHistory("history2")).called(1);
      verify(mockHistoryDao.addHistory("history1")).called(1);
      verify(mockWritingCheckHistoryDao.addAllHistory(any)).called(1);
      verify(mockTranslateHistoryDao.addAllHistory(any)).called(1);
    });

    test("should do nothing if file selection canceled", () async {
      when(mockFileHandler.readImportFile()).thenAnswer((_) async => null);

      await backupService.import();

      verifyNever(mockWordbookModel.addAllWords(any));
    });
  });
}

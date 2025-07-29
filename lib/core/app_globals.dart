import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/services/logger.dart";
import "package:flutter/material.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:logger/logger.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:shared_preferences/shared_preferences.dart";

late final Color? accentColor;
final AppDatabase mainDatabase = appDatabase();
late final PackageInfo packageInfo;
late final SharedPreferencesWithCache prefs;
late final VoidCallback refreshAll;
late final FlutterTts flutterTts;
String searchWordFromProcessText = "";
late final List<dynamic> ttsEngines;
final List<dynamic> ttsLanguages = [];
String? windowsWebview2Directory;

// Daos
final dictGroupDao = DictGroupDao(mainDatabase);
final dictionaryListDao = DictionaryListDao(mainDatabase);
final historyDao = HistoryDao(mainDatabase);
final mddAudioListDao = MddAudioListDao(mainDatabase);
final mddAudioResourceDao = MddAudioResourceDao(mainDatabase);
final wordbookDao = WordbookDao(mainDatabase);
final wordbookTagsDao = WordbookTagsDao(mainDatabase);

// Logger
final loggerOutput = MemoryOutput(bufferSize: 100);
final logger = Logger(printer: CustomLogPrinter(), output: loggerOutput);

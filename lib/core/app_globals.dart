import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:flutter/material.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:logger/logger.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:shared_preferences/shared_preferences.dart";

late final Color? accentColor;
final DictGroupDao dictGroupDao = DictGroupDao(mainDatabase);
final DictionaryListDao dictionaryListDao = DictionaryListDao(mainDatabase);
late final FlutterTts flutterTts;
final HistoryDao historyDao = HistoryDao(mainDatabase);
final AppDatabase mainDatabase = appDatabase();
final MddAudioListDao mddAudioListDao = MddAudioListDao(mainDatabase);
final MddAudioResourceDao mddAudioResourceDao =
    MddAudioResourceDao(mainDatabase);
late final PackageInfo packageInfo;
late final SharedPreferencesWithCache prefs;
late final VoidCallback refreshAll;
String searchWordFromProcessText = "";
late final List<dynamic> ttsEngines;
final List<dynamic> ttsLanguages = [];
String? windowsWebview2Directory;
final WordbookDao wordbookDao = WordbookDao(mainDatabase);
final WordbookTagsDao wordbookTagsDao = WordbookTagsDao(mainDatabase);

// Logger
final logger = Logger();

import "dart:io";

import "package:ciyue/database/app.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/pages/main/main.dart";
import "package:ciyue/pages/manage_dictionaries/main.dart";
import "package:ciyue/pages/manage_dictionaries/settings_dictionary.dart";
import "package:ciyue/pages/webview_display.dart";
import "package:ciyue/settings.dart";
import "package:drift/drift.dart";
import "package:dynamic_color/dynamic_color.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:go_router/go_router.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:path/path.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:path_provider/path_provider.dart";

Future<void> _addDictionaries(List<FileSystemEntity> entities) async {
  for (final entity in entities) {
    if (entity is File) {
      if (!entity.path.endsWith(".mdx")) continue;

      try {
        final path = setExtension(entity.path, "");
        final tmpDict = Mdict(path: path);
        if (await tmpDict.add()) {
          await tmpDict.close();
        }
        // ignore: empty_catches
      } catch (e) {}
    } else {
      final entities = await (entity as Directory).list().toList();
      await _addDictionaries(entities);
    }
  }
}

Future<void> updateAllDictionaries() async {
  final cacheDir = Directory(
      join((await getApplicationCacheDirectory()).path, "dictionaries_cache"));
  final entities = await cacheDir.list().toList();
  _addDictionaries(entities);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  prefs = await SharedPreferences.getInstance();

  int? groupId = prefs.getInt("currentDictionaryGroupId");
  if (groupId == null) {
    groupId = await dictGroupDao.addGroup("Default", []);
    await prefs.setInt("currentDictionaryGroupId", groupId);
  }
  await dictManager.setCurrentGroup(groupId);
  await dictManager.updateGroupList();

  flutterTts = FlutterTts();

  packageInfo = await PackageInfo.fromPlatform();

  platform.setMethodCallHandler((call) async {
    if (call.method == "processText") {
      final text = call.arguments as String;

      // Navigate to search result with the text
      _router.go("/word", extra: {"word": text});
    } else if (call.method == "inputDirectory") {
      updateAllDictionaries();
    }
  });

  runApp(const Dictionary());
}

const platform = MethodChannel("org.eu.mumulhl.ciyue");

final DictGroupDao dictGroupDao = DictGroupDao(mainDatabase);
final DictionaryListDao dictionaryListDao = DictionaryListDao(mainDatabase);
late final FlutterTts flutterTts;
final HistoryDao historyDao = HistoryDao(mainDatabase);
final AppDatabase mainDatabase = appDatabase();
late final PackageInfo packageInfo;
late final SharedPreferences prefs;
late final VoidCallback refreshAll;
final WordbookDao wordbookDao = WordbookDao(mainDatabase);
final WordbookTagsDao wordbookTagsDao = WordbookTagsDao(mainDatabase);

final _router = GoRouter(
  routes: [
    GoRoute(
      path: "/",
      builder: (context, state) => const Home(),
    ),
    GoRoute(
        path: "/word",
        builder: (context, state) {
          final extra = state.extra as Map<String, String>;
          return WebviewDisplay(word: extra["word"]!);
        }),
    GoRoute(
        path: "/description/:dictId",
        builder: (context, state) => WebviewDisplayDescription(
              dictId: int.parse(state.pathParameters['dictId']!),
            )),
    GoRoute(
        path: "/settings/dictionaries",
        builder: (context, state) => const ManageDictionaries()),
    GoRoute(
        path: "/settings/dictionary/:dictId",
        builder: (context, state) => SettingsDictionary(
              dictId: int.parse(state.pathParameters['dictId']!),
            )),
  ],
);

class Dictionary extends StatefulWidget {
  const Dictionary({super.key});

  @override
  State<Dictionary> createState() => _DictionaryState();
}

class _DictionaryState extends State<Dictionary> {
  @override
  Widget build(BuildContext context) {
    Locale? locale;
    if (settings.language != "system") {
      final splittedLanguage = settings.language!.split("_");
      if (splittedLanguage.length > 1) {
        locale = Locale.fromSubtags(
            languageCode: splittedLanguage[0],
            countryCode: splittedLanguage[1]);
      } else {
        locale = Locale(settings.language!);
      }
    }

    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) => MaterialApp.router(
        title: "Dictionary",
        theme: ThemeData(colorScheme: lightColorScheme),
        darkTheme: ThemeData(colorScheme: darkColorScheme),
        themeMode: settings.themeMode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    refreshAll = refresh;
  }

  void refresh() {
    setState(() {});
  }
}

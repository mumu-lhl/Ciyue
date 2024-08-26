import "package:dict_reader/dict_reader.dart";
import "package:dynamic_color/dynamic_color.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:go_router/go_router.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:shared_preferences/shared_preferences.dart";

import "database.dart";
import "pages/display_word.dart";
import "pages/home.dart";
import "pages/manage_dictionaries.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  prefs = await SharedPreferences.getInstance();
  currentDictionaryPath = prefs.getString("currentDictionaryPath");

  final themeModeString = prefs.getString("themeMode");
  switch (themeModeString) {
    case "light":
      themeMode = ThemeMode.light;
    case "dark":
      themeMode = ThemeMode.dark;
    case "system" || null:
      themeMode = ThemeMode.system;
  }

  language = prefs.getString("language");

  dictionaryList = AppDatabase();

  if (currentDictionaryPath != null) {
    currentDictionaryId = await dictionaryList.getId(currentDictionaryPath!);

    dictReader = DictReader("${currentDictionaryPath!}.mdx");
    await dictReader!.init(false);

    try {
      dictReaderResource = DictReader("${currentDictionaryPath!}.mdd");
      await dictReaderResource!.init(false);
    } catch (e) {
      dictReaderResource = null;
    }

    final id = await dictionaryList.getId(currentDictionaryPath!);
    dictionary = DictionaryDatabase(id);
  }

  flutterTts = FlutterTts();

  packageInfo = await PackageInfo.fromPlatform();

  runApp(const Dictionary());
}

int? currentDictionaryId;
String? currentDictionaryPath;
DictionaryDatabase? dictionary;
late AppDatabase dictionaryList;
DictReader? dictReader;
DictReader? dictReaderResource;
late FlutterTts flutterTts;
String? language;
late PackageInfo packageInfo;
late SharedPreferences prefs;
late VoidCallback refreshAll;
late ThemeMode themeMode;

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
          return DisplayWord(content: extra["content"]!, word: extra["word"]!);
        }),
    GoRoute(
        path: "/settings/dictionaries",
        builder: (context, state) => const ManageDictionaries()),
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
    if (language != null) {
      final splittedLanguage = language!.split("_");
      if (splittedLanguage.length > 1) {
        locale = Locale.fromSubtags(
            languageCode: splittedLanguage[0],
            countryCode: splittedLanguage[1]);
      } else {
        locale = Locale(language!);
      }
    }

    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) => MaterialApp.router(
        title: "Dictionary",
        theme: ThemeData(colorScheme: lightColorScheme),
        darkTheme: ThemeData(colorScheme: darkColorScheme),
        themeMode: themeMode,
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

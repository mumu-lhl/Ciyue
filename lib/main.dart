import "package:ciyue/database/app.dart";
import "package:ciyue/database/dictionary.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/pages/main/main.dart";
import "package:ciyue/pages/manage_dictionaries/main.dart";
import "package:ciyue/pages/manage_dictionaries/settings_dictionary.dart";
import "package:ciyue/pages/webview_display.dart";
import "package:dict_reader/dict_reader.dart";
import "package:dynamic_color/dynamic_color.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:go_router/go_router.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  prefs = await SharedPreferences.getInstance();
  dict.path = prefs.getString("currentDictionaryPath");

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
  language ??= "system";

  dictionaryList = appDatabase();

  if (dict.path != null) {
    dict.id = await dictionaryList.getId(dict.path!);

    dict.reader = DictReader("${dict.path!}.mdx");
    await dict.reader!.init(false);

    try {
      dict.readerResource = DictReader("${dict.path!}.mdd");
      await dict.readerResource!.init(false);
    } catch (e) {
      dict.readerResource = null;
    }

    final id = await dictionaryList.getId(dict.path!);
    dict.db = dictionaryDatabase(id);

    await dict.checkTagExist();
  }

  flutterTts = FlutterTts();

  packageInfo = await PackageInfo.fromPlatform();

  platform.setMethodCallHandler((call) async {
    if (call.method == "processText") {
      final text = call.arguments as String;

      late DictionaryData word;
      try {
        word = await dict.db!.getOffset(text);
      } catch (e) {
        word = await dict.db!.getOffset(text.toLowerCase());
      }

      final content = await dict.readWord(word);

      // Navigate to search result with the text
      _router.go("/word", extra: {"content": content, "word": text});
    }
  });

  runApp(const Dictionary());
}

const platform = MethodChannel("org.eu.mumulhl.ciyue/process_text");

late AppDatabase dictionaryList;
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
          return WebviewDisplay(
            content: extra["content"]!,
            word: extra["word"]!,
            description: extra.containsKey("description"),
          );
        }),
    GoRoute(
        path: "/settings/dictionaries",
        builder: (context, state) => const ManageDictionaries()),
    GoRoute(
        path: "/settings/dictionary",
        builder: (context, state) => const SettingsDictionary()),
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
    if (language != "system") {
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

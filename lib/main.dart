import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/localization_delegates.dart";
import "package:ciyue/pages/main/main.dart";
import "package:ciyue/pages/main/wordbook.dart";
import "package:ciyue/pages/manage_dictionaries/main.dart";
import "package:ciyue/pages/manage_dictionaries/properties.dart";
import "package:ciyue/pages/manage_dictionaries/settings_dictionary.dart";
import "package:ciyue/pages/settings/ai_settings.dart";
import "package:ciyue/pages/settings/audio.dart";
import "package:ciyue/pages/settings/auto_export.dart";
import "package:ciyue/pages/settings/privacy_policy.dart";
import "package:ciyue/pages/settings/terms_of_service.dart";
import "package:ciyue/pages/word_display.dart";
import "package:ciyue/services/dictionary.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/settings.dart";
import "package:ciyue/services/updater.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:drift/drift.dart" as drift;
import "package:dynamic_color/dynamic_color.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:go_router/go_router.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:path_provider/path_provider.dart";
import "package:provider/provider.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences/util/legacy_to_async_migration_util.dart";
import "package:url_launcher/url_launcher.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    const SharedPreferencesOptions sharedPreferencesOptions =
        SharedPreferencesOptions();
    final SharedPreferences legacyPrefs = await SharedPreferences.getInstance();
    await migrateLegacySharedPreferencesToSharedPreferencesAsyncIfNecessary(
      legacySharedPreferencesInstance: legacyPrefs,
      sharedPreferencesAsyncOptions: sharedPreferencesOptions,
      migrationCompletedKey: "migrationCompleted",
    );

    await initApp();

    runApp(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => WordbookModel()),
      ChangeNotifierProvider(create: (_) => HomeModel()),
      ChangeNotifierProvider(create: (_) => DictManagerModel()),
      ChangeNotifierProvider(create: (_) => HistoryModel()),
      ChangeNotifierProvider(create: (_) => ManageDictionariesModel()),
      ChangeNotifierProvider(create: (_) => AudioModel()..init()),
    ], child: const Ciyue()));
  } catch (e) {
    runApp(MaterialApp(home: CiyueError(error: e)));
  }
}

late final Color? accentColor;
final DictGroupDao dictGroupDao = DictGroupDao(mainDatabase);
final DictionaryListDao dictionaryListDao = DictionaryListDao(mainDatabase);
late final FlutterTts flutterTts;
final HistoryDao historyDao = HistoryDao(mainDatabase);
final AppDatabase mainDatabase = appDatabase();
final MddAudioListDao mddAudioListDao = MddAudioListDao(mainDatabase);
final MddAudioResourceDao mddAudioResourceDao =
    MddAudioResourceDao(mainDatabase);
final navigatorKey = GlobalKey<NavigatorState>();
late final PackageInfo packageInfo;
late final SharedPreferencesWithCache prefs;
late final VoidCallback refreshAll;
final router = GoRouter(
  navigatorKey: navigatorKey,
  routes: [
    GoRoute(
      path: "/",
      builder: (context, state) {
        return const Home();
      },
    ),
    GoRoute(
      path: "/word",
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, String>;
        return slideTransitionPageBuilder(
          key: state.pageKey,
          child: WordDisplay(word: extra["word"]!),
        );
      },
    ),
    GoRoute(
        path: "/description/:dictId",
        builder: (context, state) => WebviewDisplayDescription(
              dictId: int.parse(state.pathParameters["dictId"]!),
            )),
    GoRoute(
      path: "/settings/autoExport",
      pageBuilder: (context, state) => slideTransitionPageBuilder(
        key: state.pageKey,
        child: const AutoExport(),
      ),
    ),
    GoRoute(
      path: "/settings/dictionaries",
      pageBuilder: (context, state) => slideTransitionPageBuilder(
        key: state.pageKey,
        child: const ManageDictionaries(),
      ),
    ),
    GoRoute(
      path: "/settings/ai_settings",
      pageBuilder: (context, state) => slideTransitionPageBuilder(
        key: state.pageKey,
        child: const AiSettings(),
      ),
    ),
    GoRoute(
      path: "/settings/terms_of_service",
      pageBuilder: (context, state) => slideTransitionPageBuilder(
        key: state.pageKey,
        child: const TermsOfService(),
      ),
    ),
    GoRoute(
      path: "/settings/privacy_policy",
      pageBuilder: (context, state) => slideTransitionPageBuilder(
        key: state.pageKey,
        child: const PrivacyPolicy(),
      ),
    ),
    GoRoute(
      path: "/settings/audio",
      pageBuilder: (context, state) => slideTransitionPageBuilder(
        key: state.pageKey,
        child: const AudioSettings(),
      ),
    ),
    GoRoute(
      path: "/settings/:dictId",
      pageBuilder: (context, state) => slideTransitionPageBuilder(
        key: state.pageKey,
        child: SettingsDictionary(
          dictId: int.parse(state.pathParameters["dictId"]!),
        ),
      ),
    ),
    GoRoute(
        path: "/properties",
        builder: (context, state) => PropertiesDictionary(
              path: (state.extra as Map<String, dynamic>)["path"],
              id: (state.extra as Map<String, dynamic>)["id"],
            )),
  ],
);
String searchWordFromProcessText = "";
late final List<dynamic> ttsEngines;
final List<dynamic> ttsLanguages = [];
String? windowsWebview2Directory;
final WordbookDao wordbookDao = WordbookDao(mainDatabase);
final WordbookTagsDao wordbookTagsDao = WordbookTagsDao(mainDatabase);
@pragma("vm:entry-point")
void floatingWindow(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await initApp();

  searchWordFromProcessText = args[0];

  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => WordbookModel()),
    ChangeNotifierProvider(create: (_) => HomeModel()),
    ChangeNotifierProvider(create: (_) => DictManagerModel()),
    ChangeNotifierProvider(create: (_) => HistoryModel()),
  ], child: Ciyue(isFloatingWindow: true)));
}

Future<void> initApp() async {
  await initPrefs();

  int? groupId = prefs.getInt("currentDictionaryGroupId");
  if (groupId == null) {
    groupId = await dictGroupDao.addGroup("Default", []);
    await prefs.setInt("currentDictionaryGroupId", groupId);
  }
  await dictManager.setCurrentGroup(groupId);
  dictManager.groups = await dictGroupDao.getAllGroups();

  flutterTts = FlutterTts();

  packageInfo = await PackageInfo.fromPlatform();

  await wordbookTagsDao.loadTagsOrder();
  await wordbookTagsDao.existTag();

  if (Platform.isAndroid) {
    PlatformMethod.initHandler();
    PlatformMethod.initNotifications();

    if (settings.secureScreen) {
      PlatformMethod.setSecureFlag(true);
    }
    if (settings.notification) {
      PlatformMethod.createPersistentNotification(true);
    }
  }

  if (Platform.isWindows) {
    accentColor = await DynamicColorPlugin.getAccentColor();
  }

  if (settings.autoUpdate) {
    Updater.autoUpdate();
  }

  if (settings.ttsEngine != null) flutterTts.setEngine(settings.ttsEngine!);
  if (settings.ttsLanguage != null) {
    flutterTts.setLanguage(settings.ttsLanguage!);
  }

  Future.microtask(() async {
    if (Platform.isAndroid) {
      ttsEngines = await flutterTts.getEngines;
    }

    if (!Platform.isLinux) {
      final List<dynamic> originalTTSLanguages = await flutterTts.getLanguages;
      for (final language in originalTTSLanguages) {
        if (language is String) {
          ttsLanguages.add(language);
        }
      }
      ttsLanguages.sort((a, b) => a.toString().compareTo(b.toString()));
    }

    if (Platform.isWindows) {
      windowsWebview2Directory = (await getApplicationCacheDirectory()).path;
    }
  });
}

Future<void> initPrefs() async {
  prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(allowList: {
    "currentDictionaryGroupId",
    "exportDirectory",
    "autoExport",
    "exportFileName",
    "autoRemoveSearchWord",
    "language",
    "themeMode",
    "tagsOrder",
    "secureScreen",
    "searchBarInAppBar",
    "showSidebarIcon",
    "dictionariesDirectory",
    "exportPath",
    "notification",
    "showMoreOptionsButton",
    "skipTaggedWord",
    "aiProvider",
    "aiProviderConfigs",
    "aiExplainWord",
    "includePrereleaseUpdates",
    "explainPromptMode",
    "customExplainPrompt",
    "translatePromptMode",
    "customTranslatePrompt",
    "tabBarPosition",
    "showSearchBarInWordDisplay",
    "autoUpdate",
    "ttsEngine",
    "ttsLanguage",
    "audioDirectory",
  }));
}

CustomTransitionPage<void> slideTransitionPageBuilder({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    },
  );
}

class Ciyue extends StatefulWidget {
  final bool isFloatingWindow;

  const Ciyue({super.key, this.isFloatingWindow = false});

  @override
  State<Ciyue> createState() => _CiyueState();
}

class CiyueError extends StatelessWidget {
  final Object error;

  const CiyueError({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Error"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error.toString()),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                launchUrl(
                    Uri.parse("https://github.com/mumu-lhl/ciyue/issues"));
              },
              child: const Text("Report Issue"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: error.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Error copied to clipboard")),
                );
              },
              child: const Text("Copy Error"),
            ),
          ],
        ),
      ),
    );
  }
}

class _CiyueState extends State<Ciyue> {
  @override
  Widget build(BuildContext context) {
    if (widget.isFloatingWindow) {
      router.go("/word", extra: {"word": searchWordFromProcessText});
    }

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

    if (!Platform.isWindows) {
      return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          ColorScheme? lightColorScheme;
          ColorScheme? darkColorScheme;

          if (lightDynamic != null && darkDynamic != null) {
            lightColorScheme = lightDynamic.harmonized();
            darkColorScheme = darkDynamic.harmonized();
          }

          return buildMaterialApp(lightColorScheme, darkColorScheme, locale);
        },
      );
    } else {
      final lightColorScheme = accentColor != null
          ? ColorScheme.fromSeed(seedColor: accentColor!)
          : null;
      final darkColorScheme = accentColor != null
          ? ColorScheme.fromSeed(
              seedColor: accentColor!, brightness: Brightness.dark)
          : null;

      return buildMaterialApp(lightColorScheme, darkColorScheme, locale);
    }
  }

  MaterialApp buildMaterialApp(ColorScheme? lightColorScheme,
      ColorScheme? darkColorScheme, Locale? locale) {
    return MaterialApp.router(
      title: "Ciyue",
      theme: ThemeData(colorScheme: lightColorScheme),
      darkTheme: ThemeData(colorScheme: darkColorScheme),
      themeMode: settings.themeMode,
      locale: locale,
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        const SardinianlLocalizationDelegate(),
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
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

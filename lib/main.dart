import "dart:io";

import "package:ciyue/database/app.dart";
import "package:ciyue/pages/settings/audio.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/services/dictionary.dart";
import "package:ciyue/localization_delegates.dart";
import "package:ciyue/pages/main/main.dart";
import "package:ciyue/pages/main/wordbook.dart";
import "package:ciyue/pages/manage_dictionaries/main.dart";
import "package:ciyue/pages/manage_dictionaries/properties.dart";
import "package:ciyue/pages/manage_dictionaries/settings_dictionary.dart";
import "package:ciyue/pages/settings/ai_settings.dart";
import "package:ciyue/pages/settings/auto_export.dart";
import "package:ciyue/pages/settings/privacy_policy.dart";
import "package:ciyue/pages/settings/terms_of_service.dart";
import "package:ciyue/pages/word_display.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/updater.dart";
import "package:ciyue/services/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:drift/drift.dart" as drift;
import "package:dynamic_color/dynamic_color.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:go_router/go_router.dart";
import "package:package_info_plus/package_info_plus.dart";
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
    }));

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
        final List<dynamic> originalTTSLanguages =
            await flutterTts.getLanguages;
        for (final language in originalTTSLanguages) {
          if (language is String) {
            ttsLanguages.add(language);
          }
        }
        ttsLanguages.sort((a, b) => a.toString().compareTo(b.toString()));
      }
    });

    runApp(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => WordbookModel()),
      ChangeNotifierProvider(create: (_) => HomeModel()),
      ChangeNotifierProvider(create: (_) => DictManagerModel()),
      ChangeNotifierProvider(create: (_) => HistoryModel())
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
final navigatorKey = GlobalKey<NavigatorState>();
late final PackageInfo packageInfo;
late final SharedPreferencesWithCache prefs;
late final VoidCallback refreshAll;
late final List<dynamic> ttsEngines;
final List<dynamic> ttsLanguages = [];
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
        builder: (context, state) {
          final extra = state.extra as Map<String, String>;
          return WordDisplay(word: extra["word"]!);
        }),
    GoRoute(
        path: "/description/:dictId",
        builder: (context, state) => WebviewDisplayDescription(
              dictId: int.parse(state.pathParameters["dictId"]!),
            )),
    GoRoute(
      path: "/settings/autoExport",
      builder: (context, state) => const AutoExport(),
    ),
    GoRoute(
        path: "/settings/dictionaries",
        builder: (context, state) => const ManageDictionaries()),
    GoRoute(
        path: "/settings/ai_settings",
        builder: (context, state) => const AiSettings()),
    GoRoute(
        path: "/settings/terms_of_service",
        builder: (context, state) => const TermsOfService()),
    GoRoute(
        path: "/settings/privacy_policy",
        builder: (context, state) => const PrivacyPolicy()),
    GoRoute(
        path: "/settings/audio",
        builder: (context, state) => const AudioSettings()),
    GoRoute(
        path: "/settings/:dictId",
        builder: (context, state) => SettingsDictionary(
              dictId: int.parse(state.pathParameters["dictId"]!),
            )),
    GoRoute(
        path: "/properties",
        builder: (context, state) => PropertiesDictionary(
              path: (state.extra as Map<String, dynamic>)["path"],
            )),
  ],
);
final WordbookDao wordbookDao = WordbookDao(mainDatabase);
final WordbookTagsDao wordbookTagsDao = WordbookTagsDao(mainDatabase);

class Ciyue extends StatefulWidget {
  const Ciyue({super.key});

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

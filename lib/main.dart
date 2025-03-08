import "dart:io";

import "package:ciyue/database/app.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/pages/auto_export.dart";
import "package:ciyue/pages/main/main.dart";
import "package:ciyue/pages/manage_dictionaries/main.dart";
import "package:ciyue/pages/manage_dictionaries/properties.dart";
import "package:ciyue/pages/manage_dictionaries/settings_dictionary.dart";
import "package:ciyue/pages/webview_display.dart";
import "package:ciyue/platform.dart";
import "package:ciyue/settings.dart";
import "package:drift/drift.dart";
import "package:dynamic_color/dynamic_color.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:go_router/go_router.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences/util/legacy_to_async_migration_util.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

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
  }));

  int? groupId = prefs.getInt("currentDictionaryGroupId");
  if (groupId == null) {
    groupId = await dictGroupDao.addGroup("Default", []);
    await prefs.setInt("currentDictionaryGroupId", groupId);
  }
  await dictManager.setCurrentGroup(groupId);
  await dictManager.updateGroupList();

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

  if (Platform.isAndroid) {}

  runApp(const Ciyue());
}

final DictGroupDao dictGroupDao = DictGroupDao(mainDatabase);

final DictionaryListDao dictionaryListDao = DictionaryListDao(mainDatabase);

late final FlutterTts flutterTts;
final HistoryDao historyDao = HistoryDao(mainDatabase);
final AppDatabase mainDatabase = appDatabase();
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
        final extra =
            (state.extra as Map<String, dynamic>?) ?? {"searchWord": ""};
        return Home(searchWord: extra["searchWord"]);
      },
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

    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) => MaterialApp.router(
        title: "Ciyue",
        theme: ThemeData(colorScheme: lightColorScheme),
        darkTheme: ThemeData(colorScheme: darkColorScheme),
        themeMode: settings.themeMode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
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

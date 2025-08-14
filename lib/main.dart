import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/core/ciyue_error.dart";
import "package:ciyue/core/localization_delegates.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:ciyue/viewModels/selection_text_view_model.dart";
import "package:drift/drift.dart" as drift;
import "package:dynamic_color/dynamic_color.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_smart_dialog/flutter_smart_dialog.dart";
import "package:provider/provider.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences/util/legacy_to_async_migration_util.dart";
import "package:tray_manager/tray_manager.dart";
import "package:window_manager/window_manager.dart";

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
      ChangeNotifierProvider(create: (_) => AIPrompts()),
      ChangeNotifierProvider(create: (_) => SelectionTextViewModel()),
      Provider(create: (_) => WritingCheckHistoryDao(mainDatabase)),
      Provider(create: (_) => TranslateHistoryDao(mainDatabase)),
    ], child: const Ciyue()));
  } catch (e) {
    runApp(MaterialApp(home: CiyueError(error: e)));
  }
}

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
    ChangeNotifierProvider(create: (_) => AudioModel()..init()),
  ], child: Ciyue(isFloatingWindow: true)));
}

class Ciyue extends StatefulWidget {
  final bool isFloatingWindow;

  const Ciyue({super.key, this.isFloatingWindow = false});

  @override
  State<Ciyue> createState() => _CiyueState();
}

class _CiyueState extends State<Ciyue> with TrayListener {
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

  Widget buildMaterialApp(ColorScheme? lightColorScheme,
      ColorScheme? darkColorScheme, Locale? locale) {
    return SafeArea(
      top: false,
      child: MaterialApp.router(
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
        builder: FlutterSmartDialog.init(),
      ),
    );
  }

  @override
  void initState() {
    trayManager.addListener(this);
    super.initState();

    refreshAll = refresh;
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == "show_window") {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == "exit_app") {
      SystemNavigator.pop();
    }
  }

  void refresh() {
    setState(() {});
  }
}

import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/cloud_sync/configuration.dart";
import "package:ciyue/services/hunspell.dart";
import "package:ciyue/services/changelog.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/startup.dart";
import "package:ciyue/services/updater.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/changelog_dialog.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/home.dart";
import "package:dynamic_color/dynamic_color.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:hotkey_manager/hotkey_manager.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:path_provider/path_provider.dart";
import "package:provider/provider.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:simple_secure_storage/simple_secure_storage.dart";
import "package:tray_manager/tray_manager.dart" as tray;
import "package:window_manager/window_manager.dart";

Future<void> reloadHunspell() async {
  if (!settings.enableHunspellMorphology) {
    await hunspellManager.close();
    return;
  }

  await hunspellManager.reloadFromDatabase();
}

Future<void> initGroup() async {
  int? groupId = prefs.getInt("currentDictionaryGroupId");
  if (groupId == null) {
    groupId = await dictGroupDao.addGroup("Default", []);
    await prefs.setInt("currentDictionaryGroupId", groupId);
  }
  await dictManager.setCurrentGroup(groupId);
  dictManager.groups = await dictGroupDao.getAllGroups();

  final context = navigatorKey.currentContext;
  if (context != null && context.mounted) {
    try {
      Provider.of<HomeModel>(context, listen: false).update();
    } catch (error, stackTrace) {
      talker.error("Failed to update home model", error, stackTrace);
    }
  }
}

tray.TrayIcon? _trayIcon;
tray.ListenerId? _trayIconListenerId;
tray.Menu? _trayMenu;
tray.MenuItem? _showWindowMenuItem;
tray.MenuItem? _exitAppMenuItem;

Future<void> initTrayMenu() async {
  if (!isDesktop()) {
    return;
  }

  final context = navigatorKey.currentContext!;
  final l10n = AppLocalizations.of(context)!;

  var trayIcon = _trayIcon;
  if (trayIcon == null) {
    trayIcon = tray.TrayIcon.create();
    if (trayIcon == null) {
      throw StateError("Unable to create the system tray icon");
    }
    _trayIcon = trayIcon;

    final iconPath = Platform.isWindows
        ? "windows/runner/resources/app_icon.ico"
        : "assets/icon.png";
    final icon = Platform.isWindows
        ? tray.Image.fromFile(iconPath)
        : tray.ImageAsset.fromAsset(iconPath) ?? tray.Image.fromFile(iconPath);
    if (icon == null) {
      throw ArgumentError.value(
        iconPath,
        "iconPath",
        "Unable to load tray icon",
      );
    }
    trayIcon.icon = icon;

    // A click opens the menu natively (and exposes it to Linux StatusNotifier
    // hosts); preserve the existing right-click behavior with an event handler.
    trayIcon.setContextMenuTrigger(tray.ContextMenuTrigger.clicked);
    _trayIconListenerId = trayIcon.addListener((event) {
      if (event is tray.TrayIconRightClickedEvent) {
        _trayIcon?.openContextMenu();
      }
    });
  }

  var menu = _trayMenu;
  if (menu == null) {
    menu = tray.Menu.create();
    if (menu == null) {
      throw StateError("Unable to create the system tray menu");
    }

    final showWindowItem = tray.MenuItem.createWithLabelAndType(
      l10n.showWindow,
      tray.MenuItemType.normal,
    );
    if (showWindowItem == null) {
      throw StateError("Unable to create the show-window tray menu item");
    }
    showWindowItem.addListener((event) {
      if (event is tray.MenuItemClickedEvent) {
        windowManager.show();
        windowManager.focus();
      }
    });

    final exitAppItem = tray.MenuItem.createWithLabelAndType(
      l10n.exitApp,
      tray.MenuItemType.normal,
    );
    if (exitAppItem == null) {
      throw StateError("Unable to create the exit tray menu item");
    }
    exitAppItem.addListener((event) {
      if (event is tray.MenuItemClickedEvent) {
        SystemNavigator.pop();
      }
    });

    menu
      ..addItem(showWindowItem)
      ..addSeparator()
      ..addItem(exitAppItem);
    trayIcon.setContextMenu(menu);
    _trayMenu = menu;
    _showWindowMenuItem = showWindowItem;
    _exitAppMenuItem = exitAppItem;
  } else {
    _showWindowMenuItem!.label = l10n.showWindow;
    _exitAppMenuItem!.label = l10n.exitApp;
  }

  trayIcon.setVisible(true);
}

void disposeTrayMenu() {
  final trayIcon = _trayIcon;
  if (trayIcon != null) {
    final listenerId = _trayIconListenerId;
    if (listenerId != null) {
      trayIcon.removeListener(listenerId);
    }
    trayIcon.setContextMenu(null);
    trayIcon.setVisible(false);
  }

  _showWindowMenuItem?.dispose();
  _exitAppMenuItem?.dispose();
  _trayMenu?.dispose();
  trayIcon?.dispose();

  _trayIcon = null;
  _trayIconListenerId = null;
  _trayMenu = null;
  _showWindowMenuItem = null;
  _exitAppMenuItem = null;
}

Future<void> initApp({bool isFloatingWindow = false}) async {
  runningInFloatingWindow = isFloatingWindow;
  talker.info("Initializing application...");

  final stopWatch = Stopwatch()..start();

  if (!isFloatingWindow) {
    await SimpleSecureStorage.initialize(
      const InitializationOptions(
        appName: "Ciyue",
        namespace: "ciyue_secure_store",
      ),
    );
  }

  await initPrefs();

  await initGroup();
  unawaited(reloadHunspell());

  flutterTts = FlutterTts();

  wordbookTagsDao.loadTagsOrder();
  wordbookTagsDao.existTag();

  if (Platform.isAndroid) {
    PlatformMethod.initHandler();
    unawaited(PlatformMethod.setSecureFlag(settings.secureScreen));

    // The floating window runs in a second FlutterEngine. Do not initialize
    // process-wide notification state from it; some plugins keep a static
    // channel and the last engine would otherwise steal callbacks from the
    // main engine.
    if (!isFloatingWindow) {
      PlatformMethod.initNotifications();
      if (settings.notification) {
        PlatformMethod.createPersistentNotification(true);
      }
    }
  }

  if (isDesktop()) {
    accentColor = await DynamicColorPlugin.getAccentColor();
  }

  if (isFloatingWindow) {
    packageInfo = await PackageInfo.fromPlatform();
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = navigatorKey.currentContext!;
      final locale = Localizations.localeOf(context);

      await initTrayMenu();

      packageInfo = await PackageInfo.fromPlatform();

      if (settings.autoUpdate) {
        Updater.autoUpdate();
      }

      if (await ChangelogService.shouldShowChangelog(locale)) {
        final String changelogContent =
            await ChangelogService.getChangelogContent(locale);
        showDialog(
          context: navigatorKey.currentContext!,
          builder: (context) =>
              ChangelogDialog(changelogContent: changelogContent),
        );
        await ChangelogService.markChangelogShown();
      }
    });
  }

  stopWatch.stop();

  talker.info("Ciyue spent ${stopWatch.elapsedMilliseconds} ms initializing.");

  Future.microtask(() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // Add a delay to avoid ConcurrentModificationException in onInit on Android
      // and other potential early initialization issues on other platforms.
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    try {
      if (Platform.isAndroid && settings.ttsEngine != null) {
        await flutterTts.setEngine(settings.ttsEngine!);
      }
      if (settings.ttsLanguage != null) {
        await flutterTts.setLanguage(settings.ttsLanguage!);
      }
    } catch (e) {
      talker.error("Failed to set TTS engine or language: $e");
    }

    if (Platform.isAndroid) {
      try {
        ttsEngines = await flutterTts.getEngines;
      } catch (e) {
        talker.error("Failed to get TTS engines: $e");
      }
    }

    if (!Platform.isLinux) {
      try {
        final List<dynamic> originalTTSLanguages =
            await flutterTts.getLanguages;
        for (final language in originalTTSLanguages) {
          if (language is String) {
            ttsLanguages.add(language);
          }
        }
        ttsLanguages.sort((a, b) => a.toString().compareTo(b.toString()));
      } catch (e) {
        talker.error("Failed to get TTS languages: $e");
      }
    }

    if (Platform.isWindows) {
      windowsWebview2Directory = (await getApplicationCacheDirectory()).path;
    }

    if (isDesktop()) {
      StartupService.init();

      await hotKeyManager.unregisterAll();

      final hotKey = HotKey(
        key: PhysicalKeyboardKey.keyM,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) async {
          final isVisible = await windowManager.isVisible();
          if (isVisible) {
            final isMinimized = await windowManager.isMinimized();
            if (isMinimized) {
              windowManager.restore();
              windowManager.focus();
            } else {
              windowManager.minimize();
            }
          } else {
            windowManager.show();
            windowManager.focus();
          }
        },
      );

      await windowManager.ensureInitialized();

      WindowOptions windowOptions = WindowOptions(
        size: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    talker.info("Application initialized successfully.");
  });
}

const preferencesAllowList = <String>{
  "currentDictionaryGroupId",
  "exportDirectory",
  "autoExport",
  "exportFileName",
  "autoRemoveSearchWord",
  "language",
  "themeMode",
  "enableDynamicColor",
  "pureBlackDarkMode",
  "themeSeedColor",
  "dictionaryCustomCss",
  "dictionaryBackgroundColor",
  "dictionaryDarkReaderEnabled",
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
  "aiProviderFetchedModels",
  "aiExplainWord",
  "includePrereleaseUpdates",

  // AI Prompts
  "customExplainPrompt",
  "customTranslatePrompt",
  "customWritingCheckPrompt",

  "tabBarPosition",
  "showSearchBarInWordDisplay",
  "autoUpdate",
  "ttsEngine",
  "ttsLanguage",
  "audioDirectory",
  "advance",
  "enableHunspellMorphology",
  "hunspellLookupMode",
  "enableHistory",
  "versionCode",
  "dictionarySwitchStyle",
  "translationProvider",
  "deeplxUrl",
  "isRichOutput",
  "enableTranslationHistory",
  "enableWritingCheckHistory",
  "autoFocusSearch",
  "launchAtStartup",
  "flashcardDailyNewLimit",
  ...CloudSyncConfigurationStore.preferenceKeys,
};

Future<void> initPrefs() async {
  talker.info("Initializing shared preferences...");

  prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: preferencesAllowList,
    ),
  );

  talker.info("Shared preferences initialized successfully.");
}

import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/changelog.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/startup.dart";
import "package:ciyue/services/updater.dart";
import "package:ciyue/ui/core/changelog_dialog.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/home.dart";
import "package:dynamic_color/dynamic_color.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:hotkey_manager/hotkey_manager.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:path_provider/path_provider.dart";
import "package:provider/provider.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:tray_manager/tray_manager.dart";
import "package:window_manager/window_manager.dart";

Future<void> initGroup() async {
  int? groupId = prefs.getInt("currentDictionaryGroupId");
  if (groupId == null) {
    groupId = await dictGroupDao.addGroup("Default", []);
    await prefs.setInt("currentDictionaryGroupId", groupId);
  }
  await dictManager.setCurrentGroup(groupId);
  dictManager.groups = await dictGroupDao.getAllGroups();

  try {
    Provider.of<HomeModel>(navigatorKey.currentContext!, listen: false)
        .update();
  } catch (e) {
    talker.error(e);
  }
}

Future<void> initApp() async {
  talker.info("Initializing application...");

  final stopWatch = Stopwatch()..start();

  await initPrefs();

  // No waiting to save time.
  initGroup();

  flutterTts = FlutterTts();

  wordbookTagsDao.loadTagsOrder();
  wordbookTagsDao.existTag();

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

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final locale = Localizations.localeOf(navigatorKey.currentContext!);

    if (isDesktop()) {
      trayManager.setIcon(
        Platform.isWindows
            ? "windows/runner/resources/app_icon.ico"
            : "assets/icon.png",
      );
      Menu menu = Menu(
        items: [
          MenuItem(
            key: "show_window",
            label: "Show Window",
          ),
          MenuItem.separator(),
          MenuItem(
            key: "exit_app",
            label: "Exit App",
          ),
        ],
      );
      trayManager.setContextMenu(menu);
    }

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

Future<void> initPrefs() async {
  talker.info("Initializing shared preferences...");

  prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(allowList: {
    "currentDictionaryGroupId",
    "exportDirectory",
    "autoExport",
    "exportFileName",
    "autoRemoveSearchWord",
    "language",
    "themeMode",
    "enableDynamicColor",
    "themeSeedColor",
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
  }));

  talker.info("Shared preferences initialized successfully.");
}

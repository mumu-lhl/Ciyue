import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/changelog.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/updater.dart";
import "package:ciyue/ui/core/changelog_dialog.dart";
import "package:dynamic_color/dynamic_color.dart";
import "package:flutter/material.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:path_provider/path_provider.dart";
import "package:shared_preferences/shared_preferences.dart";

Future<void> initApp() async {
  logger.d("Initializing application...");

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

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (await ChangelogService.shouldShowChangelog()) {
      final String changelogContent =
          await ChangelogService.getChangelogContent(
              Localizations.localeOf(navigatorKey.currentContext!));
      showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) =>
            ChangelogDialog(changelogContent: changelogContent),
      );
      await ChangelogService.markChangelogShown();
    }
  });

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

    logger.d("Application initialized successfully.");
  });
}

Future<void> initPrefs() async {
  logger.d("Initializing shared preferences...");

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
  }));

  logger.d("Shared preferences initialized successfully.");
}

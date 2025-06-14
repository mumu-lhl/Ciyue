import "dart:io";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/updater.dart";
import "package:dynamic_color/dynamic_color.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:path_provider/path_provider.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:ciyue/core/app_globals.dart";

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
    "advance",
    "enableHistory",
  }));
}

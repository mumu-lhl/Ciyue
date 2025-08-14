import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:flutter/material.dart";

final settings = _Settings();

enum TabBarPosition { top, bottom }

enum DictionarySwitchStyle { expansion, tab }

class _Settings {
  late bool autoExport;
  late String exportFileName;
  late String? exportDirectory;
  late String? exportPath;

  late ThemeMode themeMode;
  String? language;
  late bool searchBarInAppBar;
  late TabBarPosition tabBarPosition;
  late bool showSidebarIcon;
  late bool showMoreOptionsButton;
  late bool showSearchBarInWordDisplay;
  late DictionarySwitchStyle dictionarySwitchStyle;

  late bool autoRemoveSearchWord;
  late bool autoFocusSearch;

  late bool secureScreen;

  late bool notification;

  late bool autoUpdate;
  late bool enableHistory;
  late bool includePrereleaseUpdates;
  late bool skipTaggedWord;
  late bool advance;

  late String aiProvider;
  late bool aiExplainWord;
  Map<String, Map<String, dynamic>> aiProviderConfigs = {};

  late String? ttsEngine;
  late String? ttsLanguage;

  late String translationProvider;
  late String? deeplxUrl;
  late bool isRichOutput;

  late bool enableTranslationHistory;
  late bool enableWritingCheckHistory;

  late bool launchAtStartup;

  _Settings() {
    launchAtStartup = prefs.getBool("launchAtStartup") ?? false;
    autoExport = prefs.getBool("autoExport") ?? false;
    exportFileName = prefs.getString("exportFileName") ?? "ciyue";
    exportDirectory = prefs.getString("exportDirectory");
    exportPath = prefs.getString("exportPath");

    autoRemoveSearchWord = prefs.getBool("autoRemoveSearchWord") ?? false;
    autoFocusSearch = prefs.getBool("autoFocusSearch") ?? false;

    secureScreen = prefs.getBool("secureScreen") ?? false;

    language = prefs.getString("language") ?? "system";
    searchBarInAppBar = prefs.getBool("searchBarInAppBar") ?? true;
    showSidebarIcon = prefs.getBool("showSidebarIcon") ?? true;
    showMoreOptionsButton = prefs.getBool("showMoreOptionsButton") ?? true;
    showSearchBarInWordDisplay =
        prefs.getBool("showSearchBarInWordDisplay") ?? true;

    final dictionarySwitchStyleString =
        prefs.getString("dictionarySwitchStyle");
    if (dictionarySwitchStyleString == null) {
      dictionarySwitchStyle = DictionarySwitchStyle.expansion;
    } else {
      dictionarySwitchStyle =
          DictionarySwitchStyle.values.byName(dictionarySwitchStyleString);
    }

    autoUpdate = prefs.getBool("autoUpdate") ?? false;
    includePrereleaseUpdates =
        prefs.getBool("includePrereleaseUpdates") ?? false;

    notification = prefs.getBool("notification") ?? false;

    enableHistory = prefs.getBool("enableHistory") ?? true;

    advance = prefs.getBool("advance") ?? false;

    skipTaggedWord = prefs.getBool("skipTaggedWord") ?? false;

    aiProvider = prefs.getString("aiProvider") ?? "openai";
    aiExplainWord = prefs.getBool("aiExplainWord") ?? false;
    translationProvider = prefs.getString("translationProvider") ?? "ai";
    deeplxUrl = prefs.getString("deeplxUrl");
    isRichOutput = prefs.getBool("isRichOutput") ?? false;

    enableTranslationHistory =
        prefs.getBool("enableTranslationHistory") ?? true;
    enableWritingCheckHistory =
        prefs.getBool("enableWritingCheckHistory") ?? true;

    ttsEngine = prefs.getString("ttsEngine");
    ttsLanguage = prefs.getString("ttsLanguage");

    var aiProviderConfigsString = prefs.getString("aiProviderConfigs");
    if (aiProviderConfigsString != null) {
      aiProviderConfigs =
          Map.castFrom<dynamic, dynamic, String, Map<String, dynamic>>(
              jsonDecode(aiProviderConfigsString));
    }

    final tabBarPositionString = prefs.getString("tabBarPosition");
    if (tabBarPositionString == null) {
      tabBarPosition = TabBarPosition.top;
    } else {
      tabBarPosition = TabBarPosition.values.byName(tabBarPositionString);
    }

    final themeModeString = prefs.getString("themeMode");
    switch (themeModeString) {
      case "light":
        themeMode = ThemeMode.light;
      case "dark":
        themeMode = ThemeMode.dark;
      case "system" || null:
        themeMode = ThemeMode.system;
    }
  }

  String get aiAPIUrl {
    return aiProviderConfigs[aiProvider]?["apiUrl"] ?? "";
  }

  Map<String, dynamic> getAiProviderConfig(String provider) {
    return aiProviderConfigs[provider] ?? {"model": "", "apiKey": ""};
  }

  Future<void> saveAiProviderConfig(
      String provider, String model, String apiKey) async {
    final currentConfig = aiProviderConfigs[provider] ?? {};
    currentConfig["model"] = model;
    currentConfig["apiKey"] = apiKey;
    aiProviderConfigs[provider] = currentConfig;
    await prefs.setString("aiProviderConfigs", jsonEncode(aiProviderConfigs));
  }

  Future<void> setAiAPIUrl(String apiUrl) async {
    aiProviderConfigs[aiProvider]!["apiUrl"] = apiUrl;
    await prefs.setString("aiProviderConfigs", jsonEncode(aiProviderConfigs));
  }

  Future<void> setTabBarPosition(TabBarPosition position) async {
    tabBarPosition = position;
    await prefs.setString("tabBarPosition", position.name);
  }

  Future<void> setDictionarySwitchStyle(DictionarySwitchStyle style) async {
    dictionarySwitchStyle = style;
    await prefs.setString("dictionarySwitchStyle", style.name);
  }

  Future<void> setAutoUpdate(bool value) async {
    autoUpdate = value;
    await prefs.setBool("autoUpdate", value);
  }

  Future<void> setTTSEngine(String engine) async {
    ttsEngine = engine;
    await prefs.setString("ttsEngine", engine);
  }

  Future<void> setTTSLanguage(String lang) async {
    ttsLanguage = lang;
    await prefs.setString("ttsLanguage", lang);
  }

  Future<void> setAdvance(bool value) async {
    advance = value;
    await prefs.setBool("advance", value);
  }

  Future<void> setEnableHistory(bool value) async {
    enableHistory = value;
    await prefs.setBool("enableHistory", value);
  }

  Future<void> setTranslationProvider(String provider) async {
    translationProvider = provider;
    await prefs.setString("translationProvider", provider);
  }

  Future<void> setDeeplxUrl(String url) async {
    deeplxUrl = url;
    await prefs.setString("deeplxUrl", url);
  }

  Future<void> setRichOutput(bool value) async {
    isRichOutput = value;
    await prefs.setBool("isRichOutput", value);
  }

  Future<void> setEnableTranslationHistory(bool value) async {
    enableTranslationHistory = value;
    await prefs.setBool("enableTranslationHistory", value);
  }

  Future<void> setEnableWritingCheckHistory(bool value) async {
    enableWritingCheckHistory = value;
    await prefs.setBool("enableWritingCheckHistory", value);
  }

  Future<void> setLaunchAtStartup(bool value) async {
    launchAtStartup = value;
    await prefs.setBool("launchAtStartup", value);
  }
}

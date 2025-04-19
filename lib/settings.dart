import 'dart:convert';

import "package:ciyue/main.dart";
import "package:flutter/material.dart";

enum TabBarPosition { top, bottom }

final settings = _Settings();

class _Settings {
  late bool autoExport;
  late String exportFileName;
  late String? exportDirectory;
  late String? exportPath;
  late ThemeMode themeMode;
  late bool autoRemoveSearchWord;
  late bool secureScreen;
  String? language;
  late bool searchBarInAppBar;
  late bool showSidebarIcon;
  late bool showMoreOptionsButton;
  late bool notification;
  late bool includePrereleaseUpdates;
  late bool skipTaggedWord;
  late String aiProvider;
  late bool aiExplainWord;
  Map<String, Map<String, dynamic>> aiProviderConfigs = {};

  late String explainPromptMode;
  late String customExplainPrompt;
  late String translatePromptMode;
  late String customTranslatePrompt;

  late TabBarPosition tabBarPosition;

  _Settings() {
    autoExport = prefs.getBool("autoExport") ?? false;
    notification = prefs.getBool("notification") ?? false;
    exportFileName = prefs.getString("exportFileName") ?? "ciyue";
    exportDirectory = prefs.getString("exportDirectory");
    exportPath = prefs.getString("exportPath");
    autoRemoveSearchWord = prefs.getBool("autoRemoveSearchWord") ?? false;
    secureScreen = prefs.getBool("secureScreen") ?? false;
    searchBarInAppBar = prefs.getBool("searchBarInAppBar") ?? true;
    showSidebarIcon = prefs.getBool("showSidebarIcon") ?? true;
    showMoreOptionsButton = prefs.getBool("showMoreOptionsButton") ?? true;
    includePrereleaseUpdates =
        prefs.getBool('includePrereleaseUpdates') ?? false;
    skipTaggedWord = prefs.getBool("skipTaggedWord") ?? false;
    language = prefs.getString("language") ?? "system";
    aiProvider = prefs.getString("aiProvider") ?? "openai";
    aiExplainWord = prefs.getBool("aiExplainWord") ?? false;

    explainPromptMode = prefs.getString("explainPromptMode") ?? "default";
    customExplainPrompt = prefs.getString("customExplainPrompt") ?? "";
    translatePromptMode = prefs.getString("translatePromptMode") ?? "default";
    customTranslatePrompt = prefs.getString("customTranslatePrompt") ?? "";

    var aiProviderConfigsString = prefs.getString('aiProviderConfigs');
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

  Future<void> setTabBarPosition(TabBarPosition position) async {
    tabBarPosition = position;
    await prefs.setString("tabBarPosition", position.name);
  }

  Map<String, dynamic> getAiProviderConfig(String provider) {
    return aiProviderConfigs[provider] ?? {'model': '', 'apiKey': ''};
  }

  Future<void> saveAiProviderConfig(
      String provider, String model, String apiKey) async {
    aiProviderConfigs[provider] = {'model': model, 'apiKey': apiKey};
    await prefs.setString('aiProviderConfigs', jsonEncode(aiProviderConfigs));
  }

  Future<void> setExplainPromptMode(String mode) async {
    explainPromptMode = mode;
    await prefs.setString("explainPromptMode", mode);
  }

  Future<void> setCustomExplainPrompt(String prompt) async {
    customExplainPrompt = prompt;
    await prefs.setString("customExplainPrompt", prompt);
  }

  Future<void> setTranslatePromptMode(String mode) async {
    translatePromptMode = mode;
    await prefs.setString("translatePromptMode", mode);
  }

  Future<void> setCustomTranslatePrompt(String prompt) async {
    customTranslatePrompt = prompt;
    await prefs.setString("customTranslatePrompt", prompt);
  }
}

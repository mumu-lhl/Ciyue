import 'dart:convert';

import "package:ciyue/main.dart";
import "package:flutter/material.dart";

final settings = _Settings();

class AIProviderConfig {
  final String provider;
  final String apiKey;
  final String model;

  AIProviderConfig(
      {required this.provider, required this.apiKey, required this.model});

  factory AIProviderConfig.fromJson(Map<String, dynamic> json) {
    return AIProviderConfig(
      provider: json["provider"]!,
      apiKey: json["apiKey"]!,
      model: json["model"]!,
    );
  }

  Map<String, String> toJson() {
    return {
      "provider": provider,
      "apiKey": apiKey,
      "model": model,
    };
  }
}

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
  late bool skipTaggedWord;
  late bool showNotFound;
  late String aiProvider;
  late List<AIProviderConfig> aiProviderConfigs;
  String? apiKey;

  _Settings() {
    autoExport = prefs.getBool("autoExport") ?? false;
    notification = prefs.getBool("notification") ?? false;
    exportFileName = prefs.getString("exportFileName") ?? "ciyue";
    exportDirectory = prefs.getString("exportDirectory");
    exportPath = prefs.getString("exportPath");
    autoRemoveSearchWord = prefs.getBool("autoRemoveSearchWord") ?? false;
    secureScreen = prefs.getBool("secureScreen") ?? false;
    searchBarInAppBar = prefs.getBool("searchBarInAppBar") ?? true;    searchBarInAppBar = prefs.getBool("searchBarInAppBar") ?? true;
    showSidebarIcon = prefs.getBool("showSidebarIcon") ?? true;
    showMoreOptionsButton = prefs.getBool("showMoreOptionsButton") ?? true;
    skipTaggedWord = prefs.getBool("skipTaggedWord") ?? false;
    showNotFound = prefs.getBool("showNotFound") ?? true;
    language = prefs.getString("language") ?? "system";
    aiProvider = prefs.getString("aiProvider") ?? "OpenAI";
    apiKey = prefs.getString("apiKey");

    aiProviderConfigs = (() {
      final aiProviderConfigsJson =
          prefs.getStringList("aiProviderConfigs") ?? [];
      return aiProviderConfigsJson
          .map((e) => AIProviderConfig.fromJson(jsonDecode(e)))
          .toList();
    })();

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

  AIProviderConfig get currentAIProviderConfig {
    return aiProviderConfigs.firstWhere(
        (config) => config.provider == aiProvider,
        orElse: () =>
            AIProviderConfig(provider: "OpenAI", apiKey: "", model: ""));
  }
}

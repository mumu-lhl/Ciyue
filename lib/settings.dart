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
  bool autoExport;
  String exportFileName;
  String? exportDirectory;
  ThemeMode themeMode;
  bool autoRemoveSearchWord;
  String? language;
  String aiProvider;
  List<AIProviderConfig> aiProviderConfigs;

  _Settings()
      : autoExport = prefs.getBool("autoExport") ?? false,
        exportFileName = prefs.getString("exportFileName") ?? "ciyue",
        exportDirectory = prefs.getString("exportDirectory"),
        autoRemoveSearchWord = prefs.getBool("autoRemoveSearchWord") ?? false,
        language = prefs.getString("language") ?? "system",
        aiProvider = prefs.getString("aiProvider") ?? "OpenAI",
        aiProviderConfigs = (() {
          final aiProviderConfigsJson =
              prefs.getStringList("aiProviderConfigs") ?? [];
          return aiProviderConfigsJson
              .map((e) => AIProviderConfig.fromJson(jsonDecode(e)))
              .toList();
        })(),
        themeMode = (() {
          final themeModeString = prefs.getString("themeMode");
          switch (themeModeString) {
            case "light":
              return ThemeMode.light;
            case "dark":
              return ThemeMode.dark;
            case "system" || null:
              return ThemeMode.system;
          }
          return ThemeMode.system;
        })();

  AIProviderConfig get currentAIProviderConfig {
    return aiProviderConfigs.firstWhere(
        (config) => config.provider == aiProvider,
        orElse: () =>
            AIProviderConfig(provider: "OpenAI", apiKey: "", model: ""));
  }
}

import "package:ciyue/main.dart";
import "package:flutter/material.dart";

final settings = _Settings();

class _Settings {
  bool autoExport;
  String exportFileName;
  String? exportDirectory;
  ThemeMode themeMode;
  bool autoRemoveSearchWord;
  String? language;
  String aiProvider;
  String? apiKey;

  _Settings()
      : autoExport = prefs.getBool("autoExport") ?? false,
        exportFileName = prefs.getString("exportFileName") ?? "ciyue",
        exportDirectory = prefs.getString("exportDirectory"),
        autoRemoveSearchWord = prefs.getBool("autoRemoveSearchWord") ?? false,
        language = prefs.getString("language") ?? "system",
        aiProvider = prefs.getString("aiProvider") ?? "OpenAI",
        apiKey = prefs.getString("apiKey"),
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
}

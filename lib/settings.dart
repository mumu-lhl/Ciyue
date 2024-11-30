import "package:ciyue/main.dart";
import "package:flutter/material.dart";

class _Settings {
  late bool autoExport;
  late ThemeMode themeMode;
  String? language;

  _Settings() {
    autoExport = prefs.getBool("autoExport") ?? false;

    language = prefs.getString("language");
    language ??= "system";

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
}

final settings = _Settings();

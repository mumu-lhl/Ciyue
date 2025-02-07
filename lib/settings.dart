import "package:ciyue/main.dart";
import "package:flutter/material.dart";

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
  late bool skipTaggedWord;
  late bool showNotFound;

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
    skipTaggedWord = prefs.getBool("skipTaggedWord") ?? false;
    showNotFound = prefs.getBool("showNotFound") ?? true;
    language = prefs.getString("language") ?? "system";

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

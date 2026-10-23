import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart" show rootBundle;
import "package:ciyue/core/app_globals.dart";

class ChangelogService {
  static Future<bool> shouldShowChangelog(Locale locale) async {
    final String? lastShownCode = prefs.getString("versionCode");
    final String currentCode = packageInfo.buildNumber;

    if (lastShownCode == null) {
      await prefs.setString("versionCode", currentCode);
      return false;
    }

    if (lastShownCode != currentCode) {
      final String content = await getChangelogContent(locale);
      if (content.trim().isEmpty) {
        return false;
      }
      return true;
    }

    return false;
  }

  /// Changelog files to try for [locale], most specific first: the full
  /// locale (`CHANGELOG.zh_CN.md`), then the language alone
  /// (`CHANGELOG.zh.md`), then the English default (`CHANGELOG.md`).
  /// The language-only step matters: regional locales like zh_CN/zh_TW
  /// have no file of their own but must still get the Chinese changelog
  /// instead of falling straight through to English.
  static List<String> changelogCandidatePaths(Locale locale) {
    return [
      if (locale.countryCode != null && locale.countryCode!.isNotEmpty)
        "changelogs/CHANGELOG.${locale.languageCode}_${locale.countryCode}.md",
      "changelogs/CHANGELOG.${locale.languageCode}.md",
      "changelogs/CHANGELOG.md",
    ];
  }

  static Future<String> getChangelogContent(Locale locale) async {
    for (final path in changelogCandidatePaths(locale)) {
      try {
        return await rootBundle.loadString(path);
      } catch (_) {
        // Try the next, less specific candidate.
      }
    }
    return "";
  }

  static Future<void> markChangelogShown() async {
    await prefs.setString("versionCode", packageInfo.buildNumber);
  }
}

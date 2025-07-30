import "package:flutter/material.dart";
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

  static Future<String> getChangelogContent(Locale locale) async {
    String changelogPath = "changelogs/CHANGELOG.${locale.languageCode}.md";
    if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
      changelogPath =
          "changelogs/CHANGELOG.${locale.languageCode}_${locale.countryCode}.md";
    }

    try {
      return await rootBundle.loadString(changelogPath);
    } catch (e) {
      return await rootBundle.loadString("changelogs/CHANGELOG.md");
    }
  }

  static Future<void> markChangelogShown() async {
    await prefs.setString("versionCode", packageInfo.buildNumber);
  }
}

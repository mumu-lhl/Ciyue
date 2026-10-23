import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart" show rootBundle;
import "package:ciyue/core/app_globals.dart";

/// One version's slice of a changelog file, with the machine-generated
/// clutter (commit links, author names) already stripped from [body].
class ChangelogSection {
  const ChangelogSection({
    required this.version,
    this.date,
    required this.body,
  });

  final String version;
  final String? date;
  final String body;
}

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

  static final _headingPattern = RegExp(
    r"^## \[([^\]]+)\]\([^)]*\)(?:\s*-\s*(\d{4}-\d{2}-\d{2}))?\s*$",
    multiLine: true,
  );

  /// Splits a changelog file into one [ChangelogSection] per version
  /// heading (`## [1.2.3](compare-url) - 2026-01-01`), newest first as
  /// written in the file. Bodies are passed through [cleanChangelogBody].
  /// Returns an empty list when no version heading matches, so callers
  /// can fall back to showing the raw file.
  static List<ChangelogSection> parseChangelogSections(String content) {
    final matches = _headingPattern.allMatches(content).toList();
    if (matches.isEmpty) {
      return const [];
    }
    final sections = <ChangelogSection>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final start = match.end;
      final end = i + 1 < matches.length
          ? matches[i + 1].start
          : content.length;
      var body = content.substring(start, end).trim();
      // Drop the horizontal rule that separates this section from the
      // next heading.
      if (body.endsWith("---")) {
        body = body.substring(0, body.length - 3).trim();
      }
      sections.add(
        ChangelogSection(
          version: match.group(1)!,
          date: match.group(2),
          body: cleanChangelogBody(body),
        ),
      );
    }
    return sections;
  }

  static final _commitTailPattern = RegExp(
    r"\s+-\s+\(\[[^\]]*\]\([^)]*\)\)\s+-\s+.*$",
  );

  /// Strips the generated tail each pre-2.0 entry carries —
  /// `- ([48dd2f4](commit-url)) - AuthorName` — leaving the readable
  /// text. Hand-written entries have no such tail and pass through
  /// unchanged. Applied at display time only; the files keep their
  /// original form for the changelog generator.
  static String cleanChangelogBody(String body) {
    return body
        .split("\n")
        .map((line) => line.replaceFirst(_commitTailPattern, "").trimRight())
        .join("\n");
  }
}

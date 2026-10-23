import "package:ciyue/services/changelog.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("changelogCandidatePaths", () {
    test("regional locale tries full name, language, then default", () {
      expect(
        ChangelogService.changelogCandidatePaths(const Locale("zh", "CN")),
        [
          "changelogs/CHANGELOG.zh_CN.md",
          "changelogs/CHANGELOG.zh.md",
          "changelogs/CHANGELOG.md",
        ],
      );
    });

    test("language-only locale skips the regional file", () {
      expect(ChangelogService.changelogCandidatePaths(const Locale("zh")), [
        "changelogs/CHANGELOG.zh.md",
        "changelogs/CHANGELOG.md",
      ]);
    });
  });

  group("getChangelogContent", () {
    test("zh_CN falls back to the Chinese changelog, not English", () async {
      final chinese = await ChangelogService.getChangelogContent(
        const Locale("zh"),
      );
      final regional = await ChangelogService.getChangelogContent(
        const Locale("zh", "CN"),
      );
      expect(regional, isNotEmpty);
      expect(regional, chinese);
    });

    test("a locale without its own file gets the English default", () async {
      final english = await ChangelogService.getChangelogContent(
        const Locale("en"),
      );
      final french = await ChangelogService.getChangelogContent(
        const Locale("fr"),
      );
      expect(english, isNotEmpty);
      expect(french, english);
    });
  });
}

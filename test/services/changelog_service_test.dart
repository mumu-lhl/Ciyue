import "dart:io" show File;

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

  group("parseChangelogSections", () {
    const sample = """
---
## [2.0.0-beta.1](https://github.com/mumu-lhl/Ciyue/compare/v1.23.2..v2.0.0-beta.1) - 2026-10-17

### Features

- **Multi-source translation** - many sources at once

---
## [1.23.2](https://github.com/mumu-lhl/Ciyue/compare/v1.23.1..1.23.2) - 2026-09-19

### Bug Fixes

- **(android)** stabilize floating window - ([48dd2f4](https://github.com/mumu-lhl/Ciyue/commit/48dd2f43f2ffc1de0318808b367bc1868b1b2319)) - Mumulhl
""";

    test("splits versions with dates, in file order", () {
      final sections = ChangelogService.parseChangelogSections(sample);
      expect(sections, hasLength(2));
      expect(sections[0].version, "2.0.0-beta.1");
      expect(sections[0].date, "2026-10-17");
      expect(sections[1].version, "1.23.2");
      expect(sections[1].date, "2026-09-19");
    });

    test("bodies drop separators, headings and commit tails", () {
      final sections = ChangelogService.parseChangelogSections(sample);
      expect(sections[0].body, contains("Multi-source translation"));
      expect(sections[0].body, isNot(contains("---")));
      expect(sections[1].body, contains("stabilize floating window"));
      expect(sections[1].body, isNot(contains("48dd2f4")));
      expect(sections[1].body, isNot(contains("Mumulhl")));
      expect(sections[1].body, isNot(contains("## [")));
    });

    test("returns empty when no version heading matches", () {
      expect(
        ChangelogService.parseChangelogSections("just some text"),
        isEmpty,
      );
    });

    test(
      "the bundled changelogs parse, newest matches the package version",
      () async {
        // The expected version comes from pubspec.yaml, not a hardcoded
        // string: a release bump updates the changelog heading, but must
        // never require touching this test. (flutter test runs from the
        // package root, so pubspec.yaml is readable here.) The test still
        // fails if a version bump forgets the changelog heading — that is
        // the failure worth catching.
        final pubspec = File("pubspec.yaml").readAsStringSync();
        final packageVersion = RegExp(
          r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.]+)?)",
          multiLine: true,
        ).firstMatch(pubspec)?.group(1);
        expect(
          packageVersion,
          isNotNull,
          reason: "pubspec.yaml must declare a version",
        );

        for (final locale in [const Locale("en"), const Locale("zh")]) {
          final content = await ChangelogService.getChangelogContent(locale);
          final sections = ChangelogService.parseChangelogSections(content);
          expect(sections.length, greaterThanOrEqualTo(4));
          expect(sections.first.version, packageVersion);
          expect(
            sections.first.date,
            matches(RegExp(r"^\d{4}-\d{2}-\d{2}$")),
            reason: "newest section must carry a release date",
          );
          for (final section in sections) {
            expect(section.body, isNot(contains("/commit/")));
          }
        }
      },
    );
  });

  group("cleanChangelogBody", () {
    test("strips generated tails and keeps readable text", () {
      const body =
          "- **(lookup)** handle redirects - ([c16c068](https://github.com/mumu-lhl/Ciyue/commit/c16c068199d703e4)) - Mumulhl\n"
          "- hand-written entry without a tail";
      final cleaned = ChangelogService.cleanChangelogBody(body);
      expect(cleaned, contains("handle redirects"));
      expect(cleaned, isNot(contains("c16c068")));
      expect(cleaned, contains("hand-written entry without a tail"));
    });
  });
}

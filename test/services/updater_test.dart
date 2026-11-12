import "package:ciyue/services/updater.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("Updater.displayVersion", () {
    test("strips a leading v from stable and preview tags", () {
      expect(Updater.displayVersion("v2.2.0"), "2.2.0");
      expect(Updater.displayVersion("v2.0.0-beta.1"), "2.0.0-beta.1");
    });

    test("keeps the rolling nightly tag intact", () {
      // Regression: substring(1) turned the tag "nightly" into "ightly".
      expect(Updater.displayVersion("nightly"), "nightly");
    });
  });

  group("Updater.nightlyUpdateAvailable", () {
    const body =
        "Latest commit: Merge pull request #845 from yx-wh/docs/word-forms-wording\n"
        "Commit hash: 7fe88820\n"
        "Build date: 2026-11-10T21:38:18Z";

    test("up to date when the installed commit matches the release body", () {
      expect(
        Updater.nightlyUpdateAvailable(
          installedCommit: "7fe88820",
          releaseBody: body,
        ),
        isFalse,
      );
    });

    test("update available when the release was built from a newer commit", () {
      expect(
        Updater.nightlyUpdateAvailable(
          installedCommit: "7fe88820",
          releaseBody: body.replaceAll("7fe88820", "cc44a723"),
        ),
        isTrue,
      );
    });

    test("falls back to reporting an update without a baked commit", () {
      expect(
        Updater.nightlyUpdateAvailable(installedCommit: "", releaseBody: body),
        isTrue,
      );
    });

    test("falls back to reporting an update when the body has no commit", () {
      expect(
        Updater.nightlyUpdateAvailable(
          installedCommit: "7fe88820",
          releaseBody: "No hash here",
        ),
        isTrue,
      );
    });
  });
}

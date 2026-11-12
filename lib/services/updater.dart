import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/core/http_client.dart";
import "package:ciyue/models/updater/updater.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/desktop_update_recovery.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/update_available.dart";
import "package:desktop_updater/desktop_updater.dart" as desktop_updater;
import "package:material_ui/material_ui.dart";
import "package:path/path.dart" as path;
import "package:path_provider/path_provider.dart";

const _defaultUpdateBaseUrl = "https://mumulhl.eu.org/Ciyue/updates/";
const _updateBaseUrl = String.fromEnvironment(
  "CIYUE_UPDATE_BASE_URL",
  defaultValue: _defaultUpdateBaseUrl,
);

// Keep this map in sync with desktop_updater.keys.json. It intentionally
// contains public material only; release signing uses the private seed in CI.
const _trustedReleasePublicKeys = <String, String>{
  "release-f3d56da10d0866ff2cff4c65":
      "Ec8ywoOp22taQ8sqwqiw5OtC5qX4COupLRBAS4Bhpj4=",
};

/// Coordinates legacy mobile update notices and signed desktop updates.
class Updater {
  static desktop_updater.DesktopUpdaterController? _desktopController;
  static Future<desktop_updater.DesktopUpdaterController?>? _initializing;

  /// Whether the signed self-update runtime is supported on this platform.
  ///
  /// macOS is excluded for now: the signed update feed and release packaging
  /// do not produce macOS entries yet, so macOS clients fall back to the
  /// legacy GitHub Releases check below.
  static bool get supportsDesktopUpdates =>
      Platform.isWindows || Platform.isLinux;

  /// Public feed URL used by the desktop updater.
  static Uri get appArchiveUrl {
    final baseUrl = _updateBaseUrl.endsWith("/")
        ? _updateBaseUrl
        : "$_updateBaseUrl/";
    return Uri.parse("${baseUrl}app-archive.json");
  }

  /// Performs a quiet update check at application startup.
  static Future<void> autoUpdate() async {
    if (supportsDesktopUpdates) {
      await _autoUpdateDesktop();
      return;
    }

    final update = await check();
    if (update.success && update.isUpdateAvailable) {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        return;
      }
      showDialog(
        context: context,
        builder: (context) => UpdateAvailable(update: update),
      );
    }
  }

  /// Checks for desktop updates and presents the package-provided update UI.
  static Future<void> checkDesktopForUpdates(BuildContext context) async {
    try {
      final controller = await _getDesktopController();
      if (controller == null || !context.mounted) {
        return;
      }

      controller.localization = _localizationFor(context);
      final result = await _checkDesktop(controller);
      if (!context.mounted) {
        return;
      }

      controller.localization = _localizationFor(context);
      await desktop_updater.showManualUpdateCheckResultDialog(
        context,
        controller: controller,
        result: result,
        showAvailableUpdate: true,
      );
    } on Object catch (error, stackTrace) {
      talker.error("Desktop update check failed: $error\n$stackTrace");
      if (context.mounted) {
        await ToastService.show(
          AppLocalizations.of(context)!.updateCheckFailed,
          context,
          type: ToastType.error,
        );
      }
    }
  }

  /// Recreates the desktop controller after the selected release channel
  /// changes.
  static Future<void> resetDesktopController() async {
    final initializing = _initializing;
    if (initializing != null) {
      try {
        await initializing;
      } catch (_) {
        // The next check will retry initialization.
      }
    }

    _desktopController?.dispose();
    _desktopController = null;
  }

  /// Checks the legacy GitHub Releases endpoint used by mobile clients.
  static Future<Update> check() async {
    final channel = settings.updateChannel;
    try {
      final response = await AppHttp.get(
        channel == UpdateChannel.stable
            ? "https://api.github.com/repos/mumu-lhl/Ciyue/releases/latest"
            : "https://api.github.com/repos/mumu-lhl/Ciyue/releases",
      );
      if (response.statusCode == 200) {
        final dynamic latestRelease;
        if (channel == UpdateChannel.stable) {
          latestRelease = response.data;
        } else if (channel == UpdateChannel.preview) {
          // Beta/Alpha: prereleases excluding nightly builds.
          latestRelease = (response.data as List).firstWhere(
            (r) =>
                !(r["prerelease"] == true &&
                    (r["name"] as String? ?? "").toLowerCase().contains(
                      "nightly",
                    )),
            orElse: () => null,
          );
        } else {
          // Nightly: only nightly builds.
          latestRelease = (response.data as List).firstWhere(
            (r) =>
                (r["name"] as String? ?? "").toLowerCase().contains("nightly"),
            orElse: () => null,
          );
        }

        if (latestRelease == null) {
          return Update(
            success: true,
            isUpdateAvailable: false,
            version: packageInfo.version,
          );
        }

        final tag = latestRelease["tag_name"].toString();
        final latestVersion = displayVersion(tag);
        return Update(
          success: true,
          isUpdateAvailable: _isUpdateAvailable(
            channel,
            latestRelease,
            latestVersion,
          ),
          version: latestVersion,
        );
      } else {
        return Update(
          success: false,
          isUpdateAvailable: false,
          version: packageInfo.version,
        );
      }
    } catch (e) {
      return Update(
        success: false,
        isUpdateAvailable: false,
        version: packageInfo.version,
      );
    }
  }

  /// The version shown for a release tag. Stable/preview tags carry a 'v'
  /// prefix (v2.2.0); the rolling nightly tag is literally "nightly", so
  /// only strip a leading 'v' — cutting the first character unconditionally
  /// turned it into "ightly".
  static String displayVersion(String tag) =>
      tag.startsWith("v") ? tag.substring(1) : tag;

  /// Whether a nightly build is newer than the installed one. Nightly
  /// builds are a single rolling release, so the tag never changes and
  /// cannot tell whether the installed build is current. Compare commit
  /// hashes instead: the nightly release body carries the commit it was
  /// built from (`Commit hash: ...`, already in the release body produced
  /// by nightly.yml), and nightly CI bakes the same short hash into the
  /// build (`--dart-define=GIT_COMMIT_HASH=...`). Builds without a baked
  /// hash (older nightlies, local builds) report an update, as before.
  static bool nightlyUpdateAvailable({
    required String installedCommit,
    required String releaseBody,
  }) {
    final latestCommit = RegExp(r"Commit hash: ([0-9a-f]+)")
        .firstMatch(releaseBody)
        ?.group(1);
    if (installedCommit.isEmpty || latestCommit == null) {
      return true;
    }
    return installedCommit != latestCommit;
  }

  static bool _isUpdateAvailable(
    UpdateChannel channel,
    Map<String, dynamic> latestRelease,
    String latestVersion,
  ) {
    if (channel == UpdateChannel.nightly) {
      final installedCommit = const String.fromEnvironment("GIT_COMMIT_HASH");
      final body = latestRelease["body"] as String? ?? "";
      return nightlyUpdateAvailable(
        installedCommit: installedCommit,
        releaseBody: body,
      );
    }
    return latestVersion != packageInfo.version;
  }

  static Future<void> _autoUpdateDesktop() async {
    try {
      final controller = await _getDesktopController();
      if (controller == null) {
        return;
      }

      final result = await _checkDesktop(controller);
      switch (result) {
        case desktop_updater.ManualUpdateCheckAvailable() ||
            desktop_updater.ManualUpdateCheckFreshInstallRequired() ||
            desktop_updater.ManualUpdateCheckBlockedBySupportPolicy():
          final context = navigatorKey.currentContext;
          if (context == null || !context.mounted) {
            return;
          }
          controller.localization = _localizationFor(context);
          await desktop_updater.showManualUpdateCheckResultDialog(
            context,
            controller: controller,
            result: result,
            showAvailableUpdate: true,
          );
        case desktop_updater.ManualUpdateCheckUpToDate() ||
            desktop_updater.ManualUpdateCheckFailed():
          return;
      }
    } on Object catch (error, stackTrace) {
      talker.error("Desktop update check failed: $error\n$stackTrace");
    }
  }

  static Future<desktop_updater.ManualUpdateCheckResult> _checkDesktop(
    desktop_updater.DesktopUpdaterController controller,
  ) async {
    await controller.recoverPendingInstall();
    return controller.checkForUpdates();
  }

  static Future<desktop_updater.DesktopUpdaterController?>
  _getDesktopController() {
    if (!supportsDesktopUpdates) {
      return Future.value(null);
    }

    final current = _desktopController;
    if (current != null) {
      return Future.value(current);
    }

    final initializing = _initializing;
    if (initializing != null) {
      return initializing;
    }

    final future = _initializeDesktopController();
    _initializing = future;
    return future.whenComplete(() {
      if (identical(_initializing, future)) {
        _initializing = null;
      }
    });
  }

  static Future<desktop_updater.DesktopUpdaterController>
  _initializeDesktopController() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final channel = _desktopChannel;
    final recoveryStore = JsonFileUpdateRecoveryStore(
      File(
        path.join(
          supportDirectory.path,
          "desktop_updater",
          "pending-install-$channel.json",
        ),
      ),
    );

    final controller = desktop_updater.DesktopUpdaterController(
      appArchiveUrl: appArchiveUrl,
      expectedPackageId: _expectedPackageId,
      trustedReleasePublicKeys: _trustedReleasePublicKeys,
      recoveryStore: recoveryStore,
      channel: channel,
      skipInitialVersionCheck: true,
    );
    _desktopController = controller;
    return controller;
  }

  static String get _desktopChannel {
    switch (settings.updateChannel) {
      case UpdateChannel.stable:
        return "stable";
      case UpdateChannel.preview:
        // Alpha and beta releases intentionally share one opt-in preview stream.
        return "preview";
      case UpdateChannel.nightly:
        return "nightly";
    }
  }

  static String get _expectedPackageId {
    if (Platform.isWindows) {
      return "ciyue";
    }
    if (Platform.isLinux) {
      return "org.eu.mumulhl.ciyue";
    }
    throw UnsupportedError("Signed desktop updates require Windows or Linux.");
  }

  static desktop_updater.DesktopUpdateLocalization _localizationFor(
    BuildContext context,
  ) {
    final locale = AppLocalizations.of(context)!;

    return desktop_updater.DesktopUpdateLocalization.resolvedBy(
      textDirection: Directionality.of(context),
      translate: (key, fallback) {
        return switch (key) {
          desktop_updater.DesktopUpdateLocalizationKey.updateAvailableText =>
            locale.updateAvailable,
          desktop_updater.DesktopUpdateLocalizationKey.restartText =>
            locale.update,
          desktop_updater.DesktopUpdateLocalizationKey.warningTitleText =>
            locale.updateAvailable,
          desktop_updater.DesktopUpdateLocalizationKey.warningCancelText =>
            locale.close,
          desktop_updater.DesktopUpdateLocalizationKey.warningConfirmText =>
            locale.update,
          desktop_updater.DesktopUpdateLocalizationKey.skipThisVersionText =>
            locale.close,
          desktop_updater.DesktopUpdateLocalizationKey.downloadText =>
            locale.update,
          desktop_updater.DesktopUpdateLocalizationKey.upToDateTitleText =>
            locale.noUpdateAvailable,
          desktop_updater.DesktopUpdateLocalizationKey.upToDateText =>
            locale.noUpdateAvailable,
          desktop_updater
              .DesktopUpdateLocalizationKey
              .updateCheckFailedTitleText =>
            locale.updateCheckFailed,
          desktop_updater.DesktopUpdateLocalizationKey.updateCheckFailedText =>
            locale.updateCheckFailed,
          desktop_updater.DesktopUpdateLocalizationKey.okText => locale.close,
          _ => fallback,
        };
      },
    );
  }
}

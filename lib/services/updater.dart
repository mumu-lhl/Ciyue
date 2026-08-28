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
    try {
      final response = await AppHttp.get(
        settings.includePrereleaseUpdates
            ? "https://api.github.com/repos/mumu-lhl/Ciyue/releases"
            : "https://api.github.com/repos/mumu-lhl/Ciyue/releases/latest",
      );
      if (response.statusCode == 200) {
        final dynamic latestRelease;
        if (settings.includePrereleaseUpdates) {
          latestRelease = (response.data as List).firstWhere(
            (r) =>
                !(r["prerelease"] == true &&
                    (r["name"] as String? ?? "").toLowerCase().contains(
                      "nightly",
                    )),
            orElse: () => null,
          );
        } else {
          latestRelease = response.data;
        }

        if (latestRelease == null) {
          return Update(
            success: true,
            isUpdateAvailable: false,
            version: packageInfo.version,
          );
        }

        final latestVersion = latestRelease["tag_name"].toString().substring(
          1,
        ); // Remove 'v' prefix
        return Update(
          success: true,
          isUpdateAvailable: latestVersion != packageInfo.version,
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
    // Alpha and beta releases intentionally share one opt-in preview stream.
    return settings.includePrereleaseUpdates ? "preview" : "stable";
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

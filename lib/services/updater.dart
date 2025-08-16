import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/models/updater/updater.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/update_available.dart";
import "package:ciyue/core/http_client.dart";
import "package:flutter/material.dart";

class Updater {
  static Future<void> autoUpdate() async {
    final update = await check();
    if (update.success && update.isUpdateAvailable) {
      showDialog(
          context: navigatorKey.currentContext!,
          builder: (context) => UpdateAvailable(update: update));
    }
  }

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
              (r) => !(r["prerelease"] == true &&
                  (r["name"] as String? ?? "")
                      .toLowerCase()
                      .contains("nightly")),
              orElse: () => null);
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

        final latestVersion = latestRelease["tag_name"]
            .toString()
            .substring(1); // Remove 'v' prefix
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
}

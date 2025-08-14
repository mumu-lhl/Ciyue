import "dart:io";

import "package:launch_at_startup/launch_at_startup.dart";
import "package:package_info_plus/package_info_plus.dart";

class StartupService {
  static Future<void> init() async {
    final packageInfo = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
      packageName: "org.eu.mumulhl.ciyue",
    );
  }

  static Future<void> setLaunchAtStartup(bool value) async {
    if (value) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}

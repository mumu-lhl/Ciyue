import 'package:ciyue/main.dart';
import 'package:ciyue/models/updater.dart';
import 'package:ciyue/settings.dart';
import 'package:dio/dio.dart';

class Updater {
  static Future<Update> check() async {
    try {
      final response = await Dio().get(
        settings.includePrereleaseUpdates
            ? 'https://api.github.com/repos/mumu-lhl/Ciyue/releases'
            : 'https://api.github.com/repos/mumu-lhl/Ciyue/releases/latest',
      );
      if (response.statusCode == 200) {
        final latestRelease = settings.includePrereleaseUpdates
            ? response.data[0]
            : response.data;
        final latestVersion = latestRelease['tag_name']
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

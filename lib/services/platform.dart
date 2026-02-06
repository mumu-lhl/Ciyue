import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/ui/pages/main/main.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/ui/core/loading_dialog.dart";
import "package:flutter/services.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:provider/provider.dart";

const _platform = MethodChannel("org.eu.mumulhl.ciyue");

class PlatformMethod {
  static Future<void> createFile(String content) async {
    await _platform.invokeMethod("createFile", content);
  }

  static Future<void> getDirectory() async {
    await _platform.invokeMethod("getDirectory");
  }

  static void initHandler() {
    _platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case "processText":
          final text = call.arguments as String;

          // Navigate to search result with the text
          router.go("/word", extra: {"word": text});
          break;

        case "inputDirectory":
          await prefs.setString(
              "dictionariesDirectory", call.arguments as String);

          final mdxFiles = await findMdxFilesOnAndroid(null);
          await selectMdx(navigatorKey.currentContext!, mdxFiles);

          break;

        case "inputAudioDirectory":
          await prefs.setString("audioDirectory", call.arguments as String);

          final paths = await findMddAudioFilesOnAndroid(null);
          await selectAudioMdd(navigatorKey.currentContext!, paths);

          break;

        case "showLoadingDialog":
          showLoadingDialog(navigatorKey.currentContext!,
              text: AppLocalizations.of(navigatorKey.currentContext!)!
                  .copyingFiles);
          break;

        case "getDirectory":
          final directory = call.arguments as String;
          settings.exportDirectory = directory;
          prefs.setString("exportDirectory", directory);
          break;
      }
    });
  }

  static Future<void> openDirectory() async {
    await _platform.invokeMethod("openDirectory");
  }

  static Future<void> openAudioDirectory() async {
    await _platform.invokeMethod("openAudioDirectory");
  }

  static Future<void> setSecureFlag(bool value) async {
    await _platform.invokeMethod("setSecureFlag", value);
  }

  static Future<void> updateDictionaries() async {
    final directory = prefs.getString("dictionariesDirectory");
    if (directory == null) {
      return;
    }

    if (!isFullFlavor()) {
      await _platform.invokeMethod("updateDictionaries", directory);
    } else {
      showLoadingDialog(navigatorKey.currentContext!);
      final paths = await findMdxFilesOnAndroid(directory);
      selectMdx(navigatorKey.currentContext!, paths);
    }
  }

  static Future<void> writeFile(Map<String, String?> info) async {
    await _platform.invokeMethod("writeFile", info);
  }

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings("ic_launcher_foreground");

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) {
          router.go("/");
          MainPage.setScreenIndex(0);

          final model = Provider.of<HomeModel>(navigatorKey.currentContext!,
              listen: false);
          model.searchWord = "";
          model.focusSearchBar();
        });
  }

  static Future<void> createPersistentNotification(bool create) async {
    if (create) {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        "persistent_notification",
        "Persistent Notification",
        channelDescription: "Persistent notification for Ciyue",
        importance: Importance.min,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
      );
      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);
      await flutterLocalNotificationsPlugin.show(
        id: 0,
        title: "Ciyue",
        body: "Ciyue is running in the background",
        notificationDetails: notificationDetails,
      );
    } else {
      await flutterLocalNotificationsPlugin.cancel(id: 0);
    }
  }
}

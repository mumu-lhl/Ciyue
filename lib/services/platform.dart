import "dart:io";

import "package:ciyue/pages/manage_dictionaries/main.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/services/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/pages/main/main.dart";
import "package:ciyue/services/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/widget/loading_dialog.dart";
import "package:flutter/services.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:provider/provider.dart";

const _platform = MethodChannel("org.eu.mumulhl.ciyue");

Future<void> _updateAllDictionaries() async {
  final documentsDir = Directory(
      join((await getApplicationSupportDirectory()).path, "dictionaries"));
  final entities = await documentsDir.list(followLinks: false).toList();
  await _addDictionaries(entities);
}

Future<void> _addDictionaries(List<FileSystemEntity> entities) async {
  for (final entity in entities) {
    if (entity is File) {
      if (!entity.path.endsWith(".mdx")) continue;
      if (await dictionaryListDao.dictionaryExist(entity.path)) continue;

      try {
        final path = setExtension(entity.path, "");
        final tmpDict = Mdict(path: path);
        if (await tmpDict.add()) {
          await tmpDict.close();
        }
        // ignore: empty_catches
      } catch (e) {}
    } else {
      final entities = await (entity as Directory).list().toList();
      await _addDictionaries(entities);
    }
  }
}

class PlatformMethod {
  static Future<void> createFile(String content) async {
    await _platform.invokeMethod("createFile", content);
  }

  static Future<void> getDirectory() async {
    await _platform.invokeMethod("getDirectory");
  }

  static Future<void> requestFloatingWindowPermission() async {
    if (Platform.isAndroid) {
      await _platform.invokeMethod("requestFloatingWindowPermission");
    }
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
          await _updateAllDictionaries();

          router.pop();

          Provider.of<ManageDictionariesModel>(navigatorKey.currentContext!,
                  listen: false)
              .update();

          break;

        case "inputAudioDirectory":
          await prefs.setString("audioDirectory", call.arguments as String);

          final paths = await findMddAudioFilesOnAndroid();
          await selectMdd(navigatorKey.currentContext!, paths);

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
    await _platform.invokeMethod("updateDictionaries", directory);
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

    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) {
      router.go("/");
      MainPage.setScreenIndex(0);

      final model =
          Provider.of<HomeModel>(navigatorKey.currentContext!, listen: false);
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
        0,
        "Ciyue",
        "Ciyue is running in the background",
        notificationDetails,
      );
    } else {
      await flutterLocalNotificationsPlugin.cancel(0);
    }
  }
}

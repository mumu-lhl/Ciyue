import "dart:io";

import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/pages/main/home.dart";
import "package:ciyue/pages/main/main.dart";
import "package:ciyue/pages/manage_dictionaries/main.dart";
import "package:ciyue/settings.dart";
import "package:ciyue/widget/loading_dialog.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import "package:provider/provider.dart";

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

class FloatingWindowViewModel extends ChangeNotifier {
  bool isReady = false;
  String text = "";

  void setText(String text) {
    this.text = text;
    isReady = true;
    notifyListeners();
  }
}

class PlatformFloatingWindow {
  static const _platform = MethodChannel("org.eu.mumulhl.ciyue/floatingWindow");

  static initHandler() {
    _platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case "process_text":
          final text = call.arguments as String;
          Provider.of<FloatingWindowViewModel>(
            floatingWindowNavigatorKey.currentContext!,
            listen: false,
          ).setText(text);
          break;
      }
    });
  }
}

class PlatformMethod {
  static const _platform = MethodChannel("org.eu.mumulhl.ciyue");

  static Future<void> createFile(String content) async {
    await _platform.invokeMethod("createFile", content);
  }

  static Future<void> getDirectory() async {
    await _platform.invokeMethod("getDirectory");
  }

  static initHandler() {
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
          updateManageDictionariesPage();
          router.pop();
          break;

        case "showLoadingDialog":
          showLoadingDialog(navigatorKey.currentContext!);
          break;

        case "getDirectory":
          final directory = call.arguments as String;
          settings.exportDirectory = directory;
          prefs.setString('exportDirectory', directory);
          break;
      }
    });
  }

  static Future<void> openDirectory() async {
    await _platform.invokeMethod("openDirectory");
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

  static Future<void> requestFloatingWindowPermission() async {
    if (Platform.isAndroid) {
      await _platform.invokeMethod("requestFloatingWindowPermission");
    }
  }

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher_foreground');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) {
      router.go("/");
      MainPage.setScreenIndex(0);
      HomePage.callEnableAutofocusOnce = true;
      HomePage.enableAutofocusOnce();
    });
  }

  static Future<void> createPersistentNotification(bool create) async {
    if (create) {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'persistent_notification',
        'Persistent Notification',
        channelDescription: 'Persistent notification for Ciyue',
        importance: Importance.min,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
      );
      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);
      await flutterLocalNotificationsPlugin.show(
        0,
        'Ciyue',
        'Ciyue is running in the background',
        notificationDetails,
      );
    } else {
      await flutterLocalNotificationsPlugin.cancel(0);
    }
  }
}

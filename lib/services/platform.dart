import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/ui/pages/main/main.dart";
import "package:ciyue/repositories/hunspell.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/ui/core/loading_dialog.dart";
import "package:flutter/services.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:provider/provider.dart";

const _platform = MethodChannel("org.eu.mumulhl.ciyue");

class _ProcessTextRequest {
  final int id;
  final String text;

  const _ProcessTextRequest({required this.id, required this.text});

  factory _ProcessTextRequest.fromPlatform(Object? arguments) {
    if (arguments is! Map) {
      throw const FormatException("Invalid process-text request");
    }

    final id = arguments["id"];
    final text = arguments["text"];
    if (id is! num || text is! String) {
      throw const FormatException("Invalid process-text request");
    }

    return _ProcessTextRequest(id: id.toInt(), text: text);
  }
}

int? _lastNavigatedProcessTextRequestId;

void navigateToProcessText(String text, {int? requestId}) {
  final normalizedText = text.trim();
  if (normalizedText.isEmpty) {
    return;
  }

  if (requestId != null) {
    final lastRequestId = _lastNavigatedProcessTextRequestId;
    if (lastRequestId != null && requestId <= lastRequestId) {
      return;
    }
    _lastNavigatedProcessTextRequestId = requestId;
  }

  searchWordFromProcessText = normalizedText;
  final location = "/word/${Uri.encodeComponent(normalizedText)}";
  // `router.state` reads the last parsed route and is unavailable while the
  // floating engine is booting, before `runApp` mounts its Navigator.
  final currentUri = router.routeInformationProvider.value.uri;
  final isAlreadyShowingWord =
      currentUri.pathSegments.length == 2 &&
      currentUri.pathSegments.first == "word" &&
      currentUri.pathSegments[1] == normalizedText;
  if (!isAlreadyShowingWord) {
    router.go(location);
  }
}

class PlatformMethod {
  static void Function()? onHunspellDirectoryImported;

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
          final request = _ProcessTextRequest.fromPlatform(call.arguments);

          try {
            navigateToProcessText(request.text, requestId: request.id);
            await _acknowledgeProcessText(request);
          } catch (error, stackTrace) {
            talker.error("Failed to handle process text", error, stackTrace);
          }
          break;

        case "inputDirectory":
          await prefs.setString(
            "dictionariesDirectory",
            call.arguments as String,
          );

          final mdxFiles = await findMdxFilesOnAndroid(null);
          await selectMdx(
            navigatorKey.currentContext!,
            mdxFiles,
            closeLoadingWhenEmpty: true,
          );
          await addHunspellPairs(await findHunspellPairsOnAndroid(null));

          break;

        case "inputHunspellDirectory":
          final context = navigatorKey.currentContext;
          try {
            await addHunspellPairs(
              await findHunspellPairsOnAndroid(null, subdirectory: "hunspell"),
            );
          } finally {
            if (context != null && context.mounted) {
              router.pop();
            }
          }
          onHunspellDirectoryImported?.call();
          break;

        case "inputAudioDirectory":
          await prefs.setString("audioDirectory", call.arguments as String);

          final paths = await findMddAudioFilesOnAndroid(null);
          await selectAudioMdd(navigatorKey.currentContext!, paths);

          break;

        case "showLoadingDialog":
          showLoadingDialog(
            navigatorKey.currentContext!,
            text: AppLocalizations.of(navigatorKey.currentContext!)!
                .copyingFiles,
          );
          break;

        case "copyDirectoryError":
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            closeLoadingDialog(context);
          }
          talker.error("Failed to copy directory: ${call.arguments}");
          break;

        case "getDirectory":
          final directory = call.arguments as String;
          settings.exportDirectory = directory;
          prefs.setString("exportDirectory", directory);
          break;
      }
    });

    unawaited(_consumePendingProcessText());
  }

  static Future<void> _consumePendingProcessText() async {
    try {
      final pending = await _platform.invokeMethod<Object?>(
        "getPendingProcessText",
      );
      if (pending == null) {
        return;
      }

      final request = _ProcessTextRequest.fromPlatform(pending);
      navigateToProcessText(request.text, requestId: request.id);
      await _acknowledgeProcessText(request);
    } catch (error, stackTrace) {
      talker.error("Failed to consume pending process text", error, stackTrace);
    }
  }

  static Future<void> _acknowledgeProcessText(
    _ProcessTextRequest request,
  ) async {
    try {
      await _platform.invokeMethod("processTextHandled", {"id": request.id});
    } catch (error, stackTrace) {
      talker.error("Failed to acknowledge process text", error, stackTrace);
    }
  }

  static Future<void> openDirectory() async {
    await _platform.invokeMethod("openDirectory");
  }

  static Future<void> openAudioDirectory() async {
    await _platform.invokeMethod("openAudioDirectory");
  }

  static Future<void> openHunspellDirectory() async {
    await _platform.invokeMethod("openHunspellDirectory");
  }

  static Future<void> setSecureFlag(bool value) async {
    try {
      await _platform.invokeMethod("setSecureFlag", value);
    } catch (error, stackTrace) {
      talker.error("Failed to set secure screen flag", error, stackTrace);
    }
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
      selectMdx(
        navigatorKey.currentContext!,
        paths,
        closeLoadingWhenEmpty: true,
      );
    }
  }

  static Future<void> writeFile(Map<String, String?> info) async {
    await _platform.invokeMethod("writeFile", info);
  }

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initNotifications() async {
    try {
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

              final model = Provider.of<HomeModel>(
                navigatorKey.currentContext!,
                listen: false,
              );
              model.searchWord = "";
              model.focusSearchBar();
            },
      );
    } catch (error, stackTrace) {
      talker.error("Failed to initialize notifications", error, stackTrace);
    }
  }

  static Future<void> createPersistentNotification(bool create) async {
    try {
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
        const NotificationDetails notificationDetails = NotificationDetails(
          android: androidNotificationDetails,
        );
        await flutterLocalNotificationsPlugin.show(
          id: 0,
          title: "Ciyue",
          body: "Ciyue is running in the background",
          notificationDetails: notificationDetails,
        );
      } else {
        await flutterLocalNotificationsPlugin.cancel(id: 0);
      }
    } catch (error, stackTrace) {
      talker.error(
        "Failed to update persistent notification",
        error,
        stackTrace,
      );
    }
  }
}

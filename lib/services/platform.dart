import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/ui/pages/main/main.dart";
import "package:ciyue/repositories/hunspell.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/ui/core/loading_dialog.dart";
import "package:flutter/services.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:ciyue/core/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

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

/// Outcome of [PlatformMethod.pickDictionaryDirectoryPath] (full flavor,
/// #800). The three cases must stay distinct: a cancelled pick is silent,
/// while an unresolvable pick falls back to the SAF-copy flow.
class DictionaryDirectoryPick {
  const DictionaryDirectoryPick._({this.path, required this.unresolvable});

  /// The user cancelled the picker.
  const DictionaryDirectoryPick.cancelled() : this._(unresolvable: false);

  /// The picked tree could not be resolved to a readable filesystem path.
  const DictionaryDirectoryPick.unresolvable() : this._(unresolvable: true);

  /// The picked tree resolved to a readable filesystem path.
  const DictionaryDirectoryPick.resolved(String path)
    : this._(path: path, unresolvable: false);

  /// The resolved filesystem path, or null when cancelled/unresolvable.
  final String? path;

  /// True when resolution failed (as opposed to the user cancelling).
  final bool unresolvable;

  bool get cancelled => path == null && !unresolvable;
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
          final ifoFiles = await findStardictFilesOnAndroid(null);
          final zimFiles = await findZimFilesOnAndroid(null);
          final mdxHandled =
              mdxFiles.isNotEmpty || (ifoFiles.isEmpty && zimFiles.isEmpty);
          if (mdxHandled) {
            await selectMdx(
              navigatorKey.currentContext!,
              mdxFiles,
              closeLoadingWhenEmpty: true,
            );
          }
          if (ifoFiles.isNotEmpty) {
            showLoadingDialog(navigatorKey.currentContext!);
            await selectStardict(
              navigatorKey.currentContext!,
              ifoFiles,
              closeLoadingWhenEmpty: true,
            );
          }
          if (zimFiles.isNotEmpty) {
            showLoadingDialog(navigatorKey.currentContext!);
            await selectZim(
              navigatorKey.currentContext!,
              zimFiles,
              closeLoadingWhenEmpty: true,
            );
          }
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

          final context = navigatorKey.currentContext;
          try {
            final paths = await findAudioPackFilesOnAndroid(null);
            if (paths.isEmpty) {
              // Nothing was copied in: close the native loading dialog
              // (selectAudioMdd would have closed it) and say why.
              if (context != null && context.mounted) {
                final message = AppLocalizations.of(context)!.noMddAudioFound;
                closeLoadingDialog(context);
                if (context.mounted) {
                  await ToastService.show(
                    message,
                    context,
                    type: ToastType.info,
                  );
                }
              }
            } else {
              final selectContext = navigatorKey.currentContext;
              if (selectContext != null && selectContext.mounted) {
                await selectAudioMdd(selectContext, paths);
              }
            }
          } catch (e) {
            talker.error("Failed to import audio directory: $e");
            final catchContext = navigatorKey.currentContext;
            if (catchContext != null && catchContext.mounted) {
              closeLoadingDialog(catchContext);
            }
          }

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
          // Shared with the non-full flavor: a failed copy used to end in
          // silence (dialog closed, nothing shown). Surface it, following
          // the inputAudioDirectory catch block below.
          if (context != null && context.mounted) {
            await ToastService.show(
              AppLocalizations.of(context)!.failedToCopyDirectory,
              context,
              type: ToastType.error,
            );
          }
          break;

        case "getDirectory":
          final directory = call.arguments as String;
          settings.exportDirectory = directory;
          prefs.setString("exportDirectory", directory);
          // Notify listeners since this bypasses a setter.
          settings.refresh();
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

  /// Asks Android to let the user pick a directory tree and resolve it to
  /// a filesystem path Dart can scan directly (full flavor, #800).
  ///
  /// Native resolution throws no exception for a cancelled pick (null),
  /// but reports an error when the tree cannot be resolved — e.g. a
  /// removable volume whose root cannot be derived. Any error, and a
  /// returned path that no longer exists, become [DictionaryDirectoryPick]
  /// unresolvable so the caller can fall back to [openDirectory].
  static Future<DictionaryDirectoryPick> pickDictionaryDirectoryPath() async {
    try {
      final path = await _platform.invokeMethod<String?>(
        "pickDictionaryDirectoryPath",
      );
      if (path == null) {
        return const DictionaryDirectoryPick.cancelled();
      }
      if (path.isEmpty || !await Directory(path).exists()) {
        talker.warning(
          "Picked dictionary directory is not a readable directory: $path",
        );
        return const DictionaryDirectoryPick.unresolvable();
      }
      return DictionaryDirectoryPick.resolved(path);
    } on PlatformException catch (error, stackTrace) {
      talker.error(
        "Failed to resolve picked dictionary directory: $error",
        error,
        stackTrace,
      );
      return const DictionaryDirectoryPick.unresolvable();
    } catch (error, stackTrace) {
      talker.error(
        "Failed to resolve picked dictionary directory: $error",
        error,
        stackTrace,
      );
      return const DictionaryDirectoryPick.unresolvable();
    }
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
      // NOTE (#800): when the last import fell back to the SAF-copy flow,
      // this pref holds a content:// URI (saved by the inputDirectory
      // handler), not a filesystem path. Scanning it as a path finds
      // nothing and reports "No dictionaries found"; the dictionaries
      // copied in by that import stay registered. Startup never reads
      // this pref, so the URI is only ever misread by this manual rescan.
      showLoadingDialog(navigatorKey.currentContext!);
      final paths = await findMdxFilesOnAndroid(directory);
      final ifoPaths = await findStardictFilesOnAndroid(directory);
      final zimPaths = await findZimFilesOnAndroid(directory);
      final mdxHandled =
          paths.isNotEmpty || (ifoPaths.isEmpty && zimPaths.isEmpty);
      if (mdxHandled) {
        selectMdx(
          navigatorKey.currentContext!,
          paths,
          closeLoadingWhenEmpty: true,
        );
      }
      if (ifoPaths.isNotEmpty) {
        if (mdxHandled) {
          showLoadingDialog(navigatorKey.currentContext!);
        }
        await selectStardict(
          navigatorKey.currentContext!,
          ifoPaths,
          closeLoadingWhenEmpty: true,
        );
      }
      if (zimPaths.isNotEmpty) {
        if (mdxHandled || ifoPaths.isNotEmpty) {
          showLoadingDialog(navigatorKey.currentContext!);
        }
        await selectZim(
          navigatorKey.currentContext!,
          zimPaths,
          closeLoadingWhenEmpty: true,
        );
      }
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

              final model = ProviderScope.containerOf(
                navigatorKey.currentContext!,
                listen: false,
              ).read(homeModelProvider);
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

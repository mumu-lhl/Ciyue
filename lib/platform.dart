import "dart:io";

import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/settings.dart";
import "package:ciyue/widget/loading_dialog.dart";
import "package:flutter/services.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

const _platform = MethodChannel("org.eu.mumulhl.ciyue");

Future<void> updateAllDictionaries() async {
  final cacheDir = Directory(
      join((await getApplicationCacheDirectory()).path, "dictionaries_cache"));
  final entities = await cacheDir.list().toList();
  await _addDictionaries(entities);
}

Future<void> _addDictionaries(List<FileSystemEntity> entities) async {
  for (final entity in entities) {
    if (entity is File) {
      if (!entity.path.endsWith(".mdx")) continue;

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

  static initHandler() {
    _platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case "processText":
          final text = call.arguments as String;

          // Navigate to search result with the text
          router.go("/word", extra: {"word": text});
          break;

        case "inputDirectory":
          await updateAllDictionaries();
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

  static Future<void> writeFile(Map<String, String?> info) async {
    await _platform.invokeMethod("writeFile", info);
  }
}

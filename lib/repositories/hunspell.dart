import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/hunspell.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

class HunspellPair {
  final String name;
  final String affPath;
  final String dicPath;

  const HunspellPair({
    required this.name,
    required this.affPath,
    required this.dicPath,
  });
}

Future<List<HunspellPair>> findHunspellPairs(Directory startDirectory) async {
  final affFiles = <String, String>{};
  final dicFiles = <String, String>{};

  await for (final entity in startDirectory.list(recursive: true)) {
    if (entity is! File) {
      continue;
    }

    final fileExtension = extension(entity.path).toLowerCase();
    if (fileExtension != ".aff" && fileExtension != ".dic") {
      continue;
    }

    final key = join(
      dirname(entity.path),
      basenameWithoutExtension(entity.path),
    ).toLowerCase();
    if (fileExtension == ".aff") {
      affFiles[key] = entity.path;
    } else {
      dicFiles[key] = entity.path;
    }
  }

  final keys = affFiles.keys.where(dicFiles.containsKey).toList(growable: false)
    ..sort();

  return [
    for (final key in keys)
      HunspellPair(
        name: basenameWithoutExtension(affFiles[key]!),
        affPath: affFiles[key]!,
        dicPath: dicFiles[key]!,
      ),
  ];
}

Future<List<HunspellPair>> findHunspellPairsOnAndroid(
  String? directory, {
  String subdirectory = "dictionaries",
}) async {
  final root = Directory(
    directory ??
        join((await getApplicationSupportDirectory()).path, subdirectory),
  );
  if (!await root.exists()) {
    return const [];
  }
  return findHunspellPairs(root);
}

Future<void> reloadHunspellFromDatabase() async {
  await hunspellManager.reloadFromDatabase();
}

Future<int> addHunspellPairs(
  Iterable<HunspellPair> pairs, {
  bool enabled = false,
}) async {
  var added = 0;
  for (final pair in pairs) {
    if (await hunspellSourceDao.exists(pair.affPath, pair.dicPath)) {
      continue;
    }

    await hunspellSourceDao.add(
      name: pair.name,
      affPath: pair.affPath,
      dicPath: pair.dicPath,
      enabled: enabled,
    );
    added++;
  }

  if (added > 0) {
    if (settings.enableHunspellMorphology) {
      await reloadHunspellFromDatabase();
    } else {
      await hunspellManager.close();
    }
  }
  return added;
}

Future<int> addHunspellPair(HunspellPair pair, {bool enabled = false}) {
  return addHunspellPairs([pair], enabled: enabled);
}

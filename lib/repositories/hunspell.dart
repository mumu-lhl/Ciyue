import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/repositories/dictionary.dart";
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

/// Reloads only the word lists that are enabled globally and members of
/// [groupId] (the current dictionary group by default).
Future<void> reloadHunspellFromDatabase({int? groupId}) async {
  if (!settings.enableHunspellMorphology) {
    await hunspellManager.close();
    return;
  }
  final group = groupId ?? dictManager.groupId;
  final memberIds = await dictGroupDao.getHunspellIds(group);
  final sources = await hunspellSourceDao.all();
  await hunspellManager.reload(
    sources
        .where((source) => source.enabled && memberIds.contains(source.id))
        .map(
          (source) => HunspellSourceInfo(
            id: source.id,
            name: source.name,
            affPath: source.affPath,
            dicPath: source.dicPath,
            language: source.language,
            enabled: true,
            order: source.order,
            twoPassLookup: source.twoPassLookup,
          ),
        ),
  );
}

Future<int> addHunspellPairs(
  Iterable<HunspellPair> pairs, {
  bool enabled = true,
}) async {
  final groupId = dictManager.groupId;
  final memberIds = await dictGroupDao.getHunspellIds(groupId);
  var added = 0;
  for (final pair in pairs) {
    if (await hunspellSourceDao.exists(pair.affPath, pair.dicPath)) {
      continue;
    }

    final id = await hunspellSourceDao.add(
      name: pair.name,
      affPath: pair.affPath,
      dicPath: pair.dicPath,
      enabled: enabled,
    );
    if (enabled) memberIds.add(id);
    added++;
  }

  if (added > 0) {
    await dictGroupDao.updateHunspellIds(groupId, memberIds);
    if (settings.enableHunspellMorphology) {
      await reloadHunspellFromDatabase(groupId: groupId);
    } else {
      await hunspellManager.close();
    }
  }
  return added;
}

Future<int> addHunspellPair(HunspellPair pair, {bool enabled = true}) {
  return addHunspellPairs([pair], enabled: enabled);
}

Future<void> setHunspellSourceInCurrentGroup(int id, bool inGroup) async {
  final groupId = dictManager.groupId;
  final memberIds = await dictGroupDao.getHunspellIds(groupId);
  if (inGroup) {
    if (!memberIds.contains(id)) memberIds.add(id);
  } else {
    memberIds.remove(id);
  }
  await dictGroupDao.updateHunspellIds(groupId, memberIds);
  if (settings.enableHunspellMorphology) {
    await reloadHunspellFromDatabase(groupId: groupId);
  }
}

Future<void> removeHunspellSource(int id) async {
  await hunspellSourceDao.remove(id);
  await dictGroupDao.removeHunspellIdFromAllGroups(id);
  if (settings.enableHunspellMorphology) {
    await reloadHunspellFromDatabase();
  }
}

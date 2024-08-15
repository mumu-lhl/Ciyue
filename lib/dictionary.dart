import "dart:io";

import "package:dict_reader/dict_reader.dart";
import "package:drift/drift.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

import "database.dart";
import "main.dart";

Future<void> addDictionary(String path) async {
  try {
    await dictionaryList.getId(path);
    return;
    // ignore: empty_catches
  } catch (e) {}

  if (dictionary != null) {
    await dictionary!.close();
  }

  await prefs.setString("currentDictionaryPath", path);

  await dictionaryList.add(path);

  final id = await dictionaryList.getId(path);
  dictionary = DictionaryDatabase(id);

  await _initDictReader(path);

  await _addWords();

  if (dictReaderResource != null) await _addResource();

  _changeCurrentDictionary(id, path);
}

Future<void> changeDictionary(int id, String path) async {
  _changeCurrentDictionary(id, path);

  await prefs.setString("currentDictionaryPath", path);

  await dictionary!.close();
  dictionary = DictionaryDatabase(id);

  _initDictReader(path);
}

Future<void> removeDictionary(String path) async {
  dictReader = null;
  dictReaderResource = null;
  _changeCurrentDictionary(null, null);

  await prefs.remove("currentDictionaryPath");

  await dictionary!.close();
  final id = await dictionaryList.getId(path);
  final databasePath = join(
      (await getApplicationDocumentsDirectory()).path, "dictionary_$id.sqlite");
  final file = File(databasePath);
  await file.delete();

  await dictionaryList.remove(path);

  try {
    final newDictionary = (await dictionaryList.all())[0];
    changeDictionary(newDictionary.id, newDictionary.path);
    // ignore: empty_catches
  } catch (e) {}
}

Future<void> _addResource() async {
  final resourceList = <ResourceCompanion>[];

  await for (final (key, (blockOffset, startOffset, endOffset, compressedSize))
      in dictReaderResource!.read()) {
    resourceList.add(ResourceCompanion(
        key: Value(key),
        blockOffset: Value(blockOffset),
        startOffset: Value(startOffset),
        endOffset: Value(endOffset),
        compressedSize: Value(compressedSize)));
  }

  await dictionary!.insertResource(resourceList);
}

Future<void> _addWords() async {
  final wordList = <DictionaryCompanion>[];

  await for (final (key, (blockOffset, startOffset, endOffset, compressedSize))
      in dictReader!.read()) {
    wordList.add(DictionaryCompanion(
        key: Value(key),
        blockOffset: Value(blockOffset),
        startOffset: Value(startOffset),
        endOffset: Value(endOffset),
        compressedSize: Value(compressedSize)));
  }

  await dictionary!.insertWords(wordList);
}

void _changeCurrentDictionary(int? id, String? path) {
  currentDictionaryId = id;
  currentDictionaryPath = path;
}

Future<void> _initDictReader(String path, {bool readKey = true}) async {
  dictReader = DictReader("$path.mdx");
  await dictReader!.init(readKey);

  try {
    dictReaderResource = DictReader("$path.mdd");
    await dictReaderResource!.init(readKey);
  } catch (e) {
    dictReaderResource = null;
  }
}

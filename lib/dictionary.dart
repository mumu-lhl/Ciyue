import "dart:io";

import "package:dict_reader/dict_reader.dart";
import "package:drift/drift.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

import "database/dictionary.dart";
import "main.dart";

Future<void> scanDictionaries(String path) async {
  final dir = Directory(path);
  final files = await dir.list().toList();

  for (final file in files) {
    if (extension(file.path) == ".mdx") {
      await addDictionary(file.path);
    }
  }
}

Future<void> addDictionary(String path) async {
  path = setExtension(path, "");

  try {
    await dictionaryList.getId(path);
    return;
    // ignore: empty_catches
  } catch (e) {}

  if (dictionary != null) {
    await dictionary!.close();
  }

  await _initDictReader(path);

  await prefs.setString("currentDictionaryPath", path);

  await dictionaryList.add(path);

  final id = await dictionaryList.getId(path);
  dictionary = dictionaryDatabase(id);

  await _addWords();

  if (dictReaderResource != null) await _addResource();

  _changeCurrentDictionary(id, path);
}

Future<void> changeDictionary(int id, String path) async {
  _changeCurrentDictionary(id, path);

  await prefs.setString("currentDictionaryPath", path);

  await dictionary!.close();
  dictionary = dictionaryDatabase(id);

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
  var number = 0;

  await for (final (key, (blockOffset, startOffset, endOffset, compressedSize))
      in dictReaderResource!.read()) {
    resourceList.add(ResourceCompanion(
        key: Value(key),
        blockOffset: Value(blockOffset),
        startOffset: Value(startOffset),
        endOffset: Value(endOffset),
        compressedSize: Value(compressedSize)));
    number++;

    if (number == 50000) {
      number = 0;
      await dictionary!.insertResource(resourceList);
      resourceList.clear();
    }
  }

  if (resourceList.isNotEmpty) {
    await dictionary!.insertResource(resourceList);
  }
}

Future<void> _addWords() async {
  final wordList = <DictionaryCompanion>[];
  var number = 0;

  await for (final (key, (blockOffset, startOffset, endOffset, compressedSize))
      in dictReader!.read()) {
    wordList.add(DictionaryCompanion(
        key: Value(key),
        blockOffset: Value(blockOffset),
        startOffset: Value(startOffset),
        endOffset: Value(endOffset),
        compressedSize: Value(compressedSize)));
    number++;

    if (number == 50000) {
      number = 0;
      await dictionary!.insertWords(wordList);
      wordList.clear();
    }
  }

  if (wordList.isNotEmpty) {
    await dictionary!.insertWords(wordList);
  }
}

void _changeCurrentDictionary(int? id, String? path) {
  currentDictionaryId = id;
  currentDictionaryPath = path;
}

Future<void> _initDictReader(String path, {bool readKey = true}) async {
  final dictReaderTemp = DictReader("$path.mdx");
  await dictReaderTemp.init(readKey);

  dictReader = dictReaderTemp;

  try {
    dictReaderResource = DictReader("$path.mdd");
    await dictReaderResource!.init(readKey);
  } catch (e) {
    dictReaderResource = null;
  }
}

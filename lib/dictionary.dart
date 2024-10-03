import "dart:io";

import "package:dict_reader/dict_reader.dart";
import "package:drift/drift.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

import "database/dictionary.dart";
import "main.dart";

Future<void> addDictionary(String path) async {
  path = setExtension(path, "");

  try {
    await dictionaryList.getId(path);
    return;
    // ignore: empty_catches
  } catch (e) {}

  if (dict.db != null) {
    await dict.db!.close();
  }

  await _initDictReader(path);

  await prefs.setString("currentDictionaryPath", path);

  await dictionaryList.add(path);

  final id = await dictionaryList.getId(path);
  dict.db = dictionaryDatabase(id);

  await _addWords();

  if (dict.readerResource != null) await _addResource();

  _changeCurrentDictionary(id, path);

  dict.customFont(null);
}

Future<void> changeDictionary(int id, String path) async {
  _changeCurrentDictionary(id, path);

  await prefs.setString("currentDictionaryPath", path);

  await dict.db!.close();
  dict.db = dictionaryDatabase(id);

  final fontPath = await dictionaryList.getFontPath(id);
  dict.customFont(fontPath);

  _initDictReader(path, readKey: false);
}

Future<void> removeDictionary(String path) async {
  dict.reader = null;
  dict.readerResource = null;
  _changeCurrentDictionary(null, null);

  await prefs.remove("currentDictionaryPath");

  await dict.db!.close();
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

Future<void> scanDictionaries(String path) async {
  final dir = Directory(path);
  final files = await dir.list().toList();

  for (final file in files) {
    if (extension(file.path) == ".mdx") {
      await addDictionary(file.path);
    }
  }
}

Future<void> _addResource() async {
  final resourceList = <ResourceCompanion>[];
  var number = 0;

  await for (final (key, (blockOffset, startOffset, endOffset, compressedSize))
      in dict.readerResource!.read()) {
    resourceList.add(ResourceCompanion(
        key: Value(key),
        blockOffset: Value(blockOffset),
        startOffset: Value(startOffset),
        endOffset: Value(endOffset),
        compressedSize: Value(compressedSize)));
    number++;

    if (number == 50000) {
      number = 0;
      await dict.db!.insertResource(resourceList);
      resourceList.clear();
    }
  }

  if (resourceList.isNotEmpty) {
    await dict.db!.insertResource(resourceList);
  }
}

Future<void> _addWords() async {
  final wordList = <DictionaryCompanion>[];
  var number = 0;

  await for (final (key, (blockOffset, startOffset, endOffset, compressedSize))
      in dict.reader!.read()) {
    wordList.add(DictionaryCompanion(
        key: Value(key),
        blockOffset: Value(blockOffset),
        startOffset: Value(startOffset),
        endOffset: Value(endOffset),
        compressedSize: Value(compressedSize)));
    number++;

    if (number == 50000) {
      number = 0;
      await dict.db!.insertWords(wordList);
      wordList.clear();
    }
  }

  if (wordList.isNotEmpty) {
    await dict.db!.insertWords(wordList);
  }
}

void _changeCurrentDictionary(int? id, String? path) {
  dict.id = id;
  dict.path = path;
}

Future<void> _initDictReader(String path, {bool readKey = true}) async {
  final dictReaderTemp = DictReader("$path.mdx");
  await dictReaderTemp.init(readKey);

  dict.reader = dictReaderTemp;

  try {
    dict.readerResource = DictReader("$path.mdd");
    await dict.readerResource!.init(readKey);
  } catch (e) {
    dict.readerResource = null;
  }
}

class Dict {
  int? id;
  String? path;
  String? fontName;
  String? fontPath;
  DictionaryDatabase? db;
  DictReader? reader;
  DictReader? readerResource;

  Future<void> customFont(String? path) async {
    fontPath = path;
    if (path == null) {
      fontName = null;
    } else {
      fontName = basename(path);
    }

    await dictionaryList.updateFont(id!, path);
  }
}

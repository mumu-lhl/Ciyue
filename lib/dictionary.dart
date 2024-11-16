import "dart:io";

import "package:dict_reader/dict_reader.dart";
import "package:drift/drift.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

import "database/dictionary.dart";
import "main.dart";

final dict = _Dict();

class _Dict {
  int? id;
  String? path;
  String? fontName;
  String? fontPath;
  String? backupPath;
  DictionaryDatabase? db;
  DictReader? reader;
  DictReader? readerResource;
  bool? tagExist;

  Future<void> addDictionary(String path) async {
    path = setExtension(path, "");

    try {
      await dictionaryList.getId(path);
      return;
      // ignore: empty_catches
    } catch (e) {}

    if (db != null) {
      await db!.close();
    }

    await _initDictReader(path);

    await prefs.setString("currentDictionaryPath", path);

    await dictionaryList.add(path);

    final id = await dictionaryList.getId(path);
    this.id = id;
    db = dictionaryDatabase(id);

    await _addWords();

    if (readerResource != null) await _addResource();

    _changeCurrentDictionary(id, path);

    customFont(null);
    customBackupPath(null);

    tagExist = false;
  }

  Future<void> changeDictionary(int id, String path) async {
    _changeCurrentDictionary(id, path);

    await prefs.setString("currentDictionaryPath", path);

    await db!.close();
    db = dictionaryDatabase(id);

    final fontPath = await dictionaryList.getFontPath(id);
    customFont(fontPath);

    final backupPath = await dictionaryList.getBackupPath(id);
    customBackupPath(backupPath);

    await checkTagExist();

    _initDictReader(path, readKey: false);
  }

  Future<void> checkTagExist() async {
    tagExist = await db!.existTag();
  }

  Future<void> customBackupPath(String? path) async {
    backupPath = path;
    await dictionaryList.updateBackup(id!, path);
  }

  Future<void> customFont(String? path) async {
    fontPath = path;
    if (path == null) {
      fontName = null;
    } else {
      fontName = basename(path);
    }

    await dictionaryList.updateFont(id!, path);
  }

  Future<void> removeDictionary(String path) async {
    reader = null;
    readerResource = null;
    _changeCurrentDictionary(null, null);

    await prefs.remove("currentDictionaryPath");

    await db!.close();
    final id = await dictionaryList.getId(path);
    final databasePath = join((await getApplicationDocumentsDirectory()).path,
        "dictionary_$id.sqlite");
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

    await for (final (
          key,
          (blockOffset, startOffset, endOffset, compressedSize)
        ) in readerResource!.read()) {
      resourceList.add(ResourceCompanion(
          key: Value(key),
          blockOffset: Value(blockOffset),
          startOffset: Value(startOffset),
          endOffset: Value(endOffset),
          compressedSize: Value(compressedSize)));
      number++;

      if (number == 50000) {
        number = 0;
        await db!.insertResource(resourceList);
        resourceList.clear();
      }
    }

    if (resourceList.isNotEmpty) {
      await db!.insertResource(resourceList);
    }
  }

  Future<void> _addWords() async {
    final wordList = <DictionaryCompanion>[];
    var number = 0;

    await for (final (
          key,
          (blockOffset, startOffset, endOffset, compressedSize)
        ) in reader!.read()) {
      wordList.add(DictionaryCompanion(
          key: Value(key),
          blockOffset: Value(blockOffset),
          startOffset: Value(startOffset),
          endOffset: Value(endOffset),
          compressedSize: Value(compressedSize)));
      number++;

      if (number == 50000) {
        number = 0;
        await db!.insertWords(wordList);
        wordList.clear();
      }
    }

    if (wordList.isNotEmpty) {
      await db!.insertWords(wordList);
    }
  }

  void _changeCurrentDictionary(int? id, String? path) {
    this.id = id;
    this.path = path;
  }

  Future<void> _initDictReader(String path, {bool readKey = true}) async {
    final dictReaderTemp = DictReader("$path.mdx");
    await dictReaderTemp.init(readKey);

    reader = dictReaderTemp;

    try {
      readerResource = DictReader("$path.mdd");
      await readerResource!.init(readKey);
    } catch (e) {
      readerResource = null;
    }
  }

  Future<String> readWord(DictionaryData word) async {
    String content = await dict.reader!.readOne(word.blockOffset,
        word.startOffset, word.endOffset, word.compressedSize);

    if (content.startsWith("@@@LINK=")) {
      // 8: remove @@@LINK=
      // content.length - 3: remove \r\n\x00
      word = await dict.db!
          .getOffset(content.substring(8, content.length - 3).trimRight());
      content = await dict.reader!.readOne(word.blockOffset, word.startOffset,
          word.endOffset, word.compressedSize);
    }

    return content;
  }
}

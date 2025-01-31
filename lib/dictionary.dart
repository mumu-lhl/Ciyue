import "dart:io";
import 'dart:convert';

import "package:ciyue/database/app.dart";
import "package:dict_reader/dict_reader.dart";
import "package:drift/drift.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

import "database/dictionary.dart";
import "main.dart";

final dictManager = DictManager();

class DictManager {
  final Map<int, Mdict> dicts = {};
  List<DictGroupData> groups = [];
  List<int> dictIds = [];
  int groupId = 0;

  bool get isEmpty => dicts.isEmpty;

  Future<void> add(String path) async {
    final dict = Mdict(path: path);
    await dict.init();
    dicts[dict.id] = dict;
  }

  Future<void> clear() async {
    for (final id in dictIds) {
      await close(id);
    }
  }

  Future<void> close(int id) async {
    await dicts[id]!.close();
    dicts.remove(id);
  }

  bool contain(int id) => dicts.keys.contains(id);

  Future<void> remove(int id) async {
    await dicts[id]!.removeDictionary();
    await dicts[id]!.close();
    dicts.remove(id);
  }

  Future<void> setCurrentGroup(int id) async {
    await clear();

    groupId = id;
    dictIds = await dictGroupDao.getDictIds(id);
    final paths = [
      for (final id in dictIds) await dictionaryListDao.getPath(id)
    ];

    int index = 0;
    for (final path in paths) {
      // Avoid the mdict that has been removed
      try {
        await add(path);
      } catch (_) {
        await dictionaryListDao.remove(path);

        final dictId = dictIds.removeAt(index);
        final databasePath = join(
            (await getApplicationDocumentsDirectory()).path,
            "dictionary_$dictId.sqlite");
        final file = File(databasePath);
        await file.delete();

        await dictGroupDao.updateDictIds(groupId, dictIds);
      }

      index += 1;
    }
  }

  Future<void> updateDictIds() async {
    dictIds = await dictGroupDao.getDictIds(groupId);
  }

  Future<void> updateGroupList() async {
    groups = await dictGroupDao.getAllGroups();
  }
}

class Mdict {
  late final int id;
  final String path;
  String? fontName;
  String? fontPath;
  late final DictionaryDatabase db;
  late final DictReader reader;
  DictReader? readerResource;
  late final String title;
  late final int entriesTotal;

  late HttpServer? server;
  late int port;

  Mdict({required this.path});

  Future<bool> add() async {
    try {
      await dictionaryListDao.getId(path);
      return false;
      // ignore: empty_catches
    } catch (e) {}

    await _initDictReader(path);

    await dictionaryListDao.add(path);

    id = await dictionaryListDao.getId(path);
    db = dictionaryDatabase(id);

    await _addWords();

    if (readerResource != null) await _addResource();

    customFont(null);

    title = reader.header["Title"] ?? basename(path);

    return true;
  }

  Future<void> close() async {
    await db.close();
  }

  Future<void> customFont(String? path) async {
    fontPath = path;
    if (path == null) {
      fontName = null;
    } else {
      fontName = basename(path);
    }

    await dictionaryListDao.updateFont(id, path);
  }

  Future<void> initOnlyMetadata() async {
    reader = DictReader("$path.mdx");
    await reader.init();

    title = reader.header["Title"] ?? basename(path);
    entriesTotal = reader.numEntries;
  }

  Future<void> init() async {
    id = await dictionaryListDao.getId(path);

    reader = DictReader("$path.mdx");
    await reader.init(false);

    try {
      readerResource = DictReader("$path.mdd");
      await readerResource!.init(false);
    } catch (e) {
      readerResource = null;
    }

    db = dictionaryDatabase(id);

    final fontPath = await dictionaryListDao.getFontPath(id);
    customFont(fontPath);

    title = reader.header["Title"] ?? basename(path);

    if (Platform.isWindows) {
      await _startServer();
    }
  }

  Future<void> _startServer() async {
    try {
      server = await HttpServer.bind("localhost", 0);
      port = server!.port;

      server!.listen((HttpRequest request) async {
        if (request.method == "POST" && request.uri.path == "/") {
          final body = await utf8.decoder.bind(request).join();
          final jsonData = json.decode(body);
          final content = jsonData["content"];
          try {
            request.response
              ..headers.contentType = ContentType.html
              ..write(content)
              ..close();
            return;
          } catch (e) {
            request.response
              ..statusCode = HttpStatus.notFound
              ..close();
            return;
          }
        } else if (request.method == "GET" && request.uri.path != "/") {
          final filename = request.uri.path.substring(1);
          final resource = await readResource(filename);
          if (resource == null) {
            request.response
              ..statusCode = HttpStatus.notFound
              ..close();
            return;
          }
          request.response
            ..headers.contentType = ContentType.parse(lookupMimeType(filename)!)
            ..add(resource)
            ..close();
          return;
        }
      });
    } catch (e) {
      server?.close();
    }
  }

  Future<List<int>?> readResource(String filename) async {
    if (filename == "favicon.ico") {
      return null;
    }

    if (filename == fontName) {
      final file = File(dictManager.dicts[id]!.fontPath!);
      final data = await file.readAsBytes();
      return data;
    }

    try {
      Uint8List? data;

      if (readerResource == null) {
        // Find resource under directory if no mdd
        final file = File("${dirname(path)}/$filename");
        data = await file.readAsBytes();
      } else {
        try {
          final result = await db.readResource(filename);
          data = await readerResource!.readOne(result.blockOffset,
              result.startOffset, result.endOffset, result.compressedSize);
        } catch (e) {
          // Find resource under directory if resource is not in mdd
          final file = File("${dirname(path)}/$filename");
          data = await file.readAsBytes();
        }
      }
      return data;
    } catch (e) {
      return null;
    }
  }

  Future<String> readWord(String word) async {
    late DictionaryData data;
    try {
      data = await db.getOffset(word);
    } catch (e) {
      data = await db.getOffset(word.toLowerCase());
    }

    String content = await reader.readOne(data.blockOffset, data.startOffset,
        data.endOffset, data.compressedSize);

    if (content.startsWith("@@@LINK=")) {
      // 8: remove @@@LINK=
      // content.length - 3: remove \r\n\x00
      data = await db
          .getOffset(content.substring(8, content.length - 3).trimRight());
      content = await reader.readOne(data.blockOffset, data.startOffset,
          data.endOffset, data.compressedSize);
    }

    return content;
  }

  Future<void> removeDictionary() async {
    await db.close();
    final databasePath = join((await getApplicationDocumentsDirectory()).path,
        "dictionary_$id.sqlite");
    final file = File(databasePath);
    await file.delete();

    await dictionaryListDao.remove(path);
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
        await db.insertResource(resourceList);
        resourceList.clear();
      }
    }

    if (resourceList.isNotEmpty) {
      await db.insertResource(resourceList);
    }
  }

  Future<void> _addWords() async {
    final wordList = <DictionaryCompanion>[];
    var number = 0;

    await for (final (
          key,
          (blockOffset, startOffset, endOffset, compressedSize)
        ) in reader.read()) {
      wordList.add(DictionaryCompanion(
          key: Value(key),
          blockOffset: Value(blockOffset),
          startOffset: Value(startOffset),
          endOffset: Value(endOffset),
          compressedSize: Value(compressedSize)));
      number++;

      if (number == 50000) {
        number = 0;
        await db.insertWords(wordList);
        wordList.clear();
      }
    }

    if (wordList.isNotEmpty) {
      await db.insertWords(wordList);
    }
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
}

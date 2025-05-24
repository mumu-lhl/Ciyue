import "dart:convert";
import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/pages/manage_dictionaries/main.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:ciyue/widget/loading_dialog.dart";
import "package:dict_reader/dict_reader.dart";
import "package:drift/drift.dart";
import "package:file_selector/file_selector.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";
import "package:provider/provider.dart";

import "../database/dictionary/dictionary.dart";
import "../main.dart";

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

  Future<void> _clear() async {
    for (final id in dictIds) {
      await close(id);
    }
  }

  Future<void> close(int id) async {
    await dicts[id]!.close();
    dicts.remove(id);
  }

  bool contain(int id) => dicts.keys.contains(id);

  Future<void> setCurrentGroup(int id) async {
    await _clear();

    groupId = id;
    dictIds = await dictGroupDao.getDictIds(id);
    final paths = [
      for (final id in dictIds) await dictionaryListDao.getPath(id)
    ];

    final toRemove = <int>[];
    for (int i = 0; i < paths.length; i++) {
      // Avoid the mdict that has been removed
      try {
        await add(paths[i]);
      } catch (_) {
        await dictionaryListDao.remove(paths[i]);
        toRemove.add(i);
      }
    }

    for (final i in toRemove.reversed) {
      final dictId = dictIds.removeAt(i);
      final databasePath =
          join((await databaseDirectory()).path, "dictionary_$dictId.sqlite");
      final file = File(databasePath);
      await file.delete();
    }

    if (toRemove.isNotEmpty) {
      await dictGroupDao.updateDictIds(groupId, dictIds);
    }
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
  late String title;
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

    title = HtmlUnescape().convert(reader.header["Title"] ?? basename(path));

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

    final alias = await dictionaryListDao.getAlias(id);
    title = HtmlUnescape().convert(alias ?? reader.header["Title"] ?? "");
    // If title in header is empty, use basename(path)
    if (title == "") {
      title = basename(path);
    }

    if (Platform.isWindows) {
      await _startServer();
    }
  }

  Future<void> initOnlyMetadata(int id) async {
    reader = DictReader("$path.mdx");
    await reader.init();

    final alias = await dictionaryListDao.getAlias(id);
    title = HtmlUnescape()
        .convert(reader.header["Title"] ?? alias ?? basename(path));
    entriesTotal = reader.numEntries;
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
    final databasePath =
        join((await databaseDirectory()).path, "dictionary_$id.sqlite");
    final file = File(databasePath);
    await file.delete();

    await dictionaryListDao.remove(path);

    if (Platform.isAndroid) {
      final mdxFile = File("$path.mdx");
      await mdxFile.delete();

      final mddFile = File("$path.mdd");
      if (await mddFile.exists()) {
        await mddFile.delete();
      }
    }
  }

  void setDefaultTitle() {
    title = HtmlUnescape().convert(reader.header["Title"] ?? basename(path));
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

        LoadingDialogContentState.updateText(
            AppLocalizations.of(navigatorKey.currentContext!)!
                .addingResource
                .replaceFirst("%s", key));
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

        LoadingDialogContentState.updateText(
            AppLocalizations.of(navigatorKey.currentContext!)!
                .addingWord
                .replaceFirst("%s", key));
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
}

Future<void> selectMdx(BuildContext context, List<String> paths) async {
  for (final path in paths) {
    if (context.mounted) {
      Mdict? tmpDict;
      try {
        final pathNoExtension = setExtension(path, "");
        tmpDict = Mdict(path: pathNoExtension);
        await tmpDict.add();
      } catch (e) {
        if (context.mounted) {
          final snackBar =
              SnackBar(content: Text(AppLocalizations.of(context)!.notSupport));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
      } finally {
        if (tmpDict != null) {
          await tmpDict.close();
        }
      }
    }

    if (paths.isNotEmpty && context.mounted) {
      context.read<ManageDictionariesModel>().update();
      context.pop();
    }
  }
}

Future<void> selectMdd(BuildContext context, List<String> paths) async {
  for (final path in paths) {
    if (await mddAudioListDao.existMddAudio(path)) {
      continue;
    }

    final reader = DictReader(path);
    await reader.init();

    int? mddAudioListId;
    if (context.mounted) {
      final title = reader.header["Title"] ?? setExtension(basename(path), "");
      mddAudioListId =
          await context.read<AudioModel>().addMddAudio(path, title);
    }

    final resources = <MddAudioResourceCompanion>[];
    int number = 0;

    await for (final (
          key,
          (blockOffset, startOffset, endOffset, compressedSize)
        ) in reader.read()) {
      if (number == 50000) {
        number = 0;
        await mddAudioResourceDao.add(resources);
        resources.clear();

        if (context.mounted) {
          LoadingDialogContentState.updateText(
              AppLocalizations.of(navigatorKey.currentContext!)!
                  .addingResource
                  .replaceFirst("%s", key));
        }
      }

      final data = MddAudioResourceCompanion(
          key: Value(key),
          blockOffset: Value(blockOffset),
          startOffset: Value(startOffset),
          endOffset: Value(endOffset),
          compressedSize: Value(compressedSize),
          mddAudioListId: Value(mddAudioListId!));
      resources.add(data);
      number++;
    }

    if (number > 0) {
      await mddAudioResourceDao.add(resources);
    }
  }

  if (paths.isNotEmpty && context.mounted) {
    context.pop();
  }
}

Future<void> selectMdxOrMdd(BuildContext context, bool isMdx) async {
  final XTypeGroup typeGroup = XTypeGroup(
    label: "${isMdx ? "MDX" : "MDD"} File",
    extensions: <String>[isMdx ? "mdx" : "mdd"],
  );

  final files = await openFiles(acceptedTypeGroups: [typeGroup]);

  if (files.isNotEmpty) {
    if (context.mounted) {
      showLoadingDialog(context, text: AppLocalizations.of(context)!.loading);
    }
  }

  if (context.mounted) {
    if (isMdx) {
      await selectMdx(context, files.map((e) => e.path).toList());
    } else {
      await selectMdd(context, files.map((e) => e.path).toList());
    }
  }
}

Future<void> findAllFileByExtension(
    Directory dir, List<String> output, String extension) async {
  final entities = await dir.list().toList();
  for (final entity in entities) {
    if (entity is File) {
      if (entity.path.endsWith(extension)) {
        output.add(entity.path);
      }
    } else if (entity is Directory) {
      await findAllFileByExtension(entity, output, extension);
    }
  }
}

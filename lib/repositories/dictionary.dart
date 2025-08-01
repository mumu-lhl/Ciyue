import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:ciyue/ui/core/loading_dialog.dart";
import "package:dict_reader/dict_reader.dart";
import "package:drift/drift.dart";
import "package:file_selector/file_selector.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:go_router/go_router.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";
import "package:provider/provider.dart";

import "../database/dictionary/dictionary.dart";

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
  List<DictReader> readerResource = [];
  late String title;
  late final int entriesTotal;

  late HttpServer? server;
  late int port;

  static const maxBatchSize = 50000;
  static const maxLoadingCount = 5000;

  Mdict({required this.path});

  Future<bool> add() async {
    await _initDictReader(path);

    await dictionaryListDao.add(path);

    id = await dictionaryListDao.getId(path);
    db = dictionaryDatabase(id);

    await _addWords();

    if (readerResource.isNotEmpty) await _addResource();

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

    final mddFile = File("$path.mdd");
    if (await mddFile.exists()) {
      final reader = DictReader(mddFile.path);
      await reader.init(false);
      readerResource.add(reader);
    }

    for (var i = 1;; i++) {
      final mddFile = File("$path.$i.mdd");
      if (await mddFile.exists()) {
        final reader = DictReader(mddFile.path);
        await reader.init(false);
        readerResource.add(reader);
      } else {
        break;
      }
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

      if (readerResource.isEmpty) {
        // Find resource under directory if no mdd
        final file = File("${dirname(path)}/$filename");
        data = await file.readAsBytes();
      } else {
        try {
          final results = await db.readResource(filename);
          for (final result in results) {
            final info = RecordOffsetInfo(result.key, result.blockOffset,
                result.startOffset, result.endOffset, result.compressedSize);
            try {
              if (result.part == null) {
                data = await readerResource[0].readOneMdd(info) as Uint8List;
              } else {
                data = await readerResource[result.part!].readOneMdd(info)
                    as Uint8List;
              }
              break;
            } catch (e) {
              continue;
            }
          }
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
    DictionaryData data;
    try {
      data = await db.getOffset(word);
    } catch (e) {
      data = await db.getOffset(word.toLowerCase());
    }

    final info = RecordOffsetInfo(data.key, data.blockOffset, data.startOffset,
        data.endOffset, data.compressedSize);

    String content = await reader.readOneMdx(info);

    if (content.startsWith("@@@LINK=")) {
      final newData = await db.getOffset(content
          .replaceFirst("@@@LINK=", "")
          .replaceAll(RegExp(r"[\n\r\x00]"), "")
          .trimRight());
      final newInfo = RecordOffsetInfo(newData.key, newData.blockOffset,
          newData.startOffset, newData.endOffset, newData.compressedSize);
      content = await reader.readOneMdx(newInfo);
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

    if (Platform.isAndroid && appFlavor != "full") {
      final mdxFile = File("$path.mdx");
      await mdxFile.delete();

      final mddFile = File("$path.mdd");
      if (await mddFile.exists()) {
        await mddFile.delete();
      }

      for (var i = 1;; i++) {
        final mddFile = File("$path.$i.mdd");
        if (await mddFile.exists()) {
          await mddFile.delete();
        } else {
          break;
        }
      }
    }
  }

  void setDefaultTitle() {
    title = HtmlUnescape().convert(reader.header["Title"] ?? basename(path));
  }

  Future<void> _addResource() async {
    for (var i = 0; i < readerResource.length; i++) {
      final resourceList = <ResourceCompanion>[];
      var number = 0;
      var loadingCount = 0;

      await for (final info in readerResource[i].readWithOffset()) {
        resourceList.add(ResourceCompanion(
            key: Value(info.keyText),
            blockOffset: Value(info.recordBlockOffset),
            startOffset: Value(info.startOffset),
            endOffset: Value(info.endOffset),
            compressedSize: Value(info.compressedSize),
            part: i == 0 ? Value(null) : Value(i)));
        number++;
        loadingCount++;

        if (number == maxBatchSize) {
          number = 0;
          await db.insertResource(resourceList);
          resourceList.clear();
        }

        if (loadingCount == maxLoadingCount) {
          LoadingDialogContentState.updateText(
              AppLocalizations.of(navigatorKey.currentContext!)!
                  .addingResource(info.keyText));
          loadingCount = 0;
        }
      }

      if (resourceList.isNotEmpty) {
        await db.insertResource(resourceList);
      }
    }
  }

  Future<void> _addWords() async {
    final wordList = <DictionaryCompanion>[];
    var number = 0;
    var loadingCount = 0;

    await for (final info in reader.readWithOffset()) {
      wordList.add(DictionaryCompanion(
          key: Value(info.keyText),
          blockOffset: Value(info.recordBlockOffset),
          startOffset: Value(info.startOffset),
          endOffset: Value(info.endOffset),
          compressedSize: Value(info.compressedSize)));
      number++;
      loadingCount++;

      if (number == maxBatchSize) {
        number = 0;
        await db.insertWords(wordList);
        wordList.clear();
      }

      if (loadingCount == maxLoadingCount) {
        LoadingDialogContentState.updateText(
            AppLocalizations.of(navigatorKey.currentContext!)!
                .addingWord(info.keyText));
        loadingCount = 0;
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

    final mddFile = File("$path.mdd");
    if (await mddFile.exists()) {
      final reader = DictReader(mddFile.path);
      await reader.init(readKey);
      readerResource.add(reader);
    }

    for (var i = 1;; i++) {
      final mddFile = File("$path.$i.mdd");
      if (await mddFile.exists()) {
        final reader = DictReader(mddFile.path);
        await reader.init(readKey);
        readerResource.add(reader);
      } else {
        break;
      }
    }
  }

  Future<void> _startServer() async {
    try {
      server = await HttpServer.bind("localhost", 0);
      port = server!.port;
      talker.info("HTTP server started on port $port");

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
    final pathNoExtension = setExtension(path, "");

    if (await dictionaryListDao.dictionaryExist(pathNoExtension)) {
      continue;
    }

    Mdict? tmpDict;
    tmpDict = Mdict(path: pathNoExtension);

    try {
      await tmpDict.add();
      talker.info("Added dictionary: $pathNoExtension");
    } catch (e) {
      if (context.mounted) {
        ToastService.show(AppLocalizations.of(context)!.notSupport, context,
            type: ToastType.error);
        talker.error("Failed to add dictionary: $pathNoExtension, error: $e", e,
            StackTrace.current);
      }
    }

    await tmpDict.close();

    // Why? Don't know. Strange!
    continue;
  }

  if (paths.isNotEmpty && context.mounted) {
    context.read<ManageDictionariesModel>().update();
    context.pop();
  }
}

Future<void> selectAudioMdd(BuildContext context, List<String> paths) async {
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
    var number = 0;
    var loadingCount = 0;

    await for (final info in reader.readWithOffset()) {
      if (number == Mdict.maxBatchSize) {
        number = 0;
        await mddAudioResourceDao.add(resources);
        resources.clear();
      }

      if (loadingCount == Mdict.maxLoadingCount) {
        LoadingDialogContentState.updateText(
            AppLocalizations.of(navigatorKey.currentContext!)!
                .addingResource(info.keyText));
        loadingCount = 0;
      }

      final data = MddAudioResourceCompanion(
          key: Value(info.keyText),
          blockOffset: Value(info.recordBlockOffset),
          startOffset: Value(info.startOffset),
          endOffset: Value(info.endOffset),
          compressedSize: Value(info.compressedSize),
          mddAudioListId: Value(mddAudioListId!));
      resources.add(data);

      number++;
      loadingCount++;
    }

    if (number > 0) {
      await mddAudioResourceDao.add(resources);
    }
  }

  if (paths.isNotEmpty && context.mounted) {
    context.pop();
  }
}

Future<void> selectMdxOrMddOnDesktop(BuildContext context, bool isMdx) async {
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
      await selectAudioMdd(context, files.map((e) => e.path).toList());
    }
  }
}

Future<void> findAllFileByExtension(
    Directory startDir, List<String> output, String extension) async {
  final entities = await startDir.list().toList();
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

Future<List<String>> findMdxFilesOnAndroid(String? directory) async {
  final documentsDir = Directory(directory ??
      join((await getApplicationSupportDirectory()).path, "dictionaries"));
  final mdxFiles = <String>[];
  await findAllFileByExtension(documentsDir, mdxFiles, "mdx");

  return mdxFiles;
}

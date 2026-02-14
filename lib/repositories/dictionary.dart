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

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool get isEmpty => dicts.isEmpty;

  Future<void> add(int id, String path) async {
    final dict = Mdict(path: path);
    dict.init();
    dicts[id] = dict;
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
    _isLoading = true;

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
        await add(dictIds[i], paths[i]);
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
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (toRemove.isNotEmpty) {
      await dictGroupDao.updateDictIds(groupId, dictIds);
    }

    _isLoading = false;
  }
}

class Mdict {
  late int id;
  final String path;
  String? fontName;
  String? fontPath;
  late final DictReader reader;
  List<DictReader> readerResources = [];
  late String title;
  late final int entriesTotal;

  late final int type;

  bool hasCss = false;
  bool hasJs = false;

  late HttpServer? server;
  int port = 0;

  static const maxBatchSize = 50000;
  static const maxLoadingCount = 5000;

  bool isLoading = true;

  Mdict({required this.path});

  Future<void> add() async {
    reader = DictReader("$path.mdx");
    await reader.initDict(readKeys: false, readRecordBlockInfo: false);

    title = reader.header["Title"] ?? basename(path);

    await dictionaryListDao.add(path, title);
    isLoading = false;
  }

  Future<void> close() async {
    await reader.close();

    for (final readerResource in readerResources) {
      await readerResource.close();
    }
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

  void Function() saveCache(int id, String type, DictReader reader) {
    return () async {
      final cacheFileName = "dict_reader_${id.toString()}_$type.cache";
      final cacheDir = await getApplicationCacheDirectory();
      final cacheFile = File(join(cacheDir.path, cacheFileName));

      if (await cacheFile.exists()) {
        return;
      }

      final cacheData = await reader.exportCacheAsString();
      await cacheFile.writeAsString(cacheData);

      if (type == "mdx") {
        isLoading = false;
      }
    };
  }

  Future<bool> hitCache(int id, String type, DictReader reader) async {
    final cacheFileName = "dict_reader_${id.toString()}_$type.cache";
    final cacheDir = await getApplicationCacheDirectory();
    final cacheFile = File(join(cacheDir.path, cacheFileName));

    final cacheExist = await cacheFile.exists();
    if (!cacheExist) {
      return false;
    }

    try {
      final cache = await cacheFile.readAsString();
      reader.importCacheFromString(cache).then((_) {
        if (type == "mdx") {
          isLoading = false;
        }
      }, onError: (e) {
        if (type == "mdx") {
          isLoading = false;
        }
        talker.error("Failed to import cache for $id ($type): $e");
        cacheFile.delete().catchError((_) => cacheFile);
      });

      return true;
    } catch (_) {
      if (cacheExist) {
        await cacheFile.delete();
      }
      return false;
    }
  }

  Future<void> _getTitle() async {
    final titleInDatabase = await dictionaryListDao.getTitle(id);
    final title = HtmlUnescape()
        .convert(titleInDatabase ?? reader.header["Title"] ?? basename(path));

    if (title == "") {
      this.title = basename(path);
    } else {
      this.title = title;
    }
  }

  Future<void> init() async {
    id = await dictionaryListDao.getId(path);
    type = await dictionaryListDao.getType(id);

    reader = DictReader("$path.mdx");

    await reader.initDict(readKeys: false, readRecordBlockInfo: false);

    initDictReaders();

    final fontPath = await dictionaryListDao.getFontPath(id);
    customFont(fontPath);

    await _getTitle();

    await _checkResources();

    if (Platform.isWindows || Platform.isLinux) {
      await _startServer();
    }
  }

  Future<void> initDictReaders() async {
    if (!await hitCache(id, "mdx", reader)) {
      reader.setOnRecordBlockInfoRead(saveCache(id, "mdx", reader));
      reader.initDict(readHeader: false);
    }

    final mddFile = File("$path.mdd");
    if (await mddFile.exists()) {
      final reader = DictReader(mddFile.path);

      if (!await hitCache(id, "mdd", reader)) {
        reader.setOnRecordBlockInfoRead(saveCache(id, "mdd", reader));
        reader.initDict();
      } else {
        reader.initDict(readKeys: false, readRecordBlockInfo: false);
      }

      readerResources.add(reader);
    }

    for (var i = 1;; i++) {
      final mddFile = File("$path.$i.mdd");
      if (await mddFile.exists()) {
        final reader = DictReader(mddFile.path);

        if (!await hitCache(id, "$i.mdd", reader)) {
          reader.setOnRecordBlockInfoRead(saveCache(id, "$i.mdd", reader));
          reader.initDict();
        } else {
          reader.initDict(readKeys: false, readRecordBlockInfo: false);
        }

        readerResources.add(reader);
      } else {
        break;
      }
    }
  }

  Future<void> _checkResources() async {
    final name = basename(path);
    final cssName = "$name.css";
    final jsName = "$name.js";

    // Check filesystem
    final cssFile = File("${dirname(path)}/$cssName");
    hasCss = await cssFile.exists();
    final jsFile = File("${dirname(path)}/$jsName");
    hasJs = await jsFile.exists();

    // Check MDD
    if (!hasCss || !hasJs) {
      if (!hasCss) {
        final results = await readResource(cssName);
        hasCss = results.isNotEmpty;
      }
      if (!hasJs) {
        final results = await readResource(jsName);
        hasJs = results.isNotEmpty;
      }
    }
  }

  Future<void> initOnlyMetadata(int id) async {
    this.id = id;

    reader = DictReader("$path.mdx");

    if (await hitCache(id, "mdx", reader)) {
      await reader.initDict(readKeys: false, readRecordBlockInfo: false);
    } else {
      await reader.initDict(readRecordBlockInfo: false);
      reader.setOnRecordBlockInfoRead(saveCache(id, "mdx", reader));
    }

    await waitForLoading();

    await _getTitle();

    await _checkResources();

    entriesTotal = reader.numEntries;
  }

  Future<void> waitForLoading() async {
    while (isLoading) {
      await Future.delayed(Duration(milliseconds: 40));
    }
  }

  Future<List<int>?> _readResourceDesktop(String filename) async {
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

      if (readerResources.isEmpty) {
        // Find resource under directory if no mdd
        final file = File("${dirname(path)}/$filename");
        data = await file.readAsBytes();
      } else {
        try {
          final results = await readResource(filename);
          for (final result in results) {
            final info = RecordOffsetInfo(result.key, result.blockOffset,
                result.startOffset, result.endOffset, result.compressedSize);
            try {
              if (result.part == null) {
                data = await readerResources[0].readOneMdd(info) as Uint8List;
              } else {
                data = await readerResources[result.part!].readOneMdd(info)
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
    await waitForLoading();

    List<RecordOffsetInfo> data;

    if (reader.exist(word)) {
      data = await locateAll(word);
    } else if (reader.exist(word.toLowerCase())) {
      data = await locateAll(word.toLowerCase());
    } else {
      throw Exception("Word not found: $word");
    }

    final contents = <String>[];
    for (final info in data) {
      contents.add(await reader.readOneMdx(info));
    }

    final content = contents.join();

    if (content.startsWith("@@@LINK=")) {
      contents.clear();

      final newData = await locateAll(content
          .replaceFirst("@@@LINK=", "")
          .replaceAll(RegExp(r"[\n\r\x00]"), "")
          .trimRight());
      if (newData.isEmpty) {
        throw Exception(
            "Linked word not found: ${content.replaceFirst("@@@LINK=", "")}");
      }

      for (final info in newData) {
        contents.add(await reader.readOneMdx(info));
      }
    }

    return wrapContentWithResources(contents.join());
  }

  String wrapContentWithResources(String content) {
    final name = basename(path);
    final encodedName = Uri.encodeComponent(name);
    String header = "";
    if (hasCss) {
      header += '<link rel="stylesheet" href="$encodedName.css">\n';
    }
    if (hasJs) {
      header += '<script src="$encodedName.js"></script>\n';
    }
    return header + content;
  }

  Future<void> removeDictionary() async {
    if (type == 0) {
      final databasePath =
          join((await databaseDirectory()).path, "dictionary_$id.sqlite");
      final file = File(databasePath);
      await file.delete();
    }

    await dictionaryListDao.remove(path);

    if (Platform.isAndroid && !isFullFlavor()) {
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

  Future<List<String>> search(String query) async {
    await waitForLoading();

    try {
      return reader.search(query, limit: 30);
    } catch (e) {
      return [];
    }
  }

  Future<List<RecordOffsetInfo>> locateAll(String word) async {
    await waitForLoading();

    return await reader.locateAll(word);
  }

  Future<bool> wordExist(String word) async {
    await waitForLoading();

    if (reader.exist(word)) {
      return true;
    } else if (reader.exist(word.toLowerCase())) {
      return true;
    } else {
      return false;
    }
  }

  Future<List<ResourceData>> readResource(String key) async {
    final resourceData = <ResourceData>[];

    final normalizedKey = key.replaceAll("/", "\\");
    final keysToTry = [
      normalizedKey,
      normalizedKey.startsWith("\\")
          ? normalizedKey.substring(1)
          : "\\$normalizedKey",
    ];

    for (final readerResource in readerResources) {
      String? foundKey;
      for (final k in keysToTry) {
        if (readerResource.exist(k)) {
          foundKey = k;
          break;
        }
      }

      if (foundKey == null) {
        continue;
      }

      final offsetInfo = await readerResource.locate(foundKey);

      if (offsetInfo == null) {
        continue;
      }

      final part = readerResources.indexOf(readerResource);

      resourceData.add(ResourceData(
        key: offsetInfo.keyText,
        blockOffset: offsetInfo.recordBlockOffset,
        startOffset: offsetInfo.startOffset,
        endOffset: offsetInfo.endOffset,
        compressedSize: offsetInfo.compressedSize,
        part: part == -1 ? null : part,
      ));
    }

    return resourceData;
  }

  Future<void> _startServer() async {
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
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
          final resource = await _readResourceDesktop(filename);
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

Future<void> selectMdx(BuildContext context, List<String> paths,
    {bool closeLoadingWhenEmpty = false}) async {
  if (paths.isEmpty) {
    if (closeLoadingWhenEmpty && context.mounted) {
      context.pop();
    }
    return;
  }

  for (final path in paths) {
    final pathNoExtension = setExtension(path, "");

    if (await dictionaryListDao.dictionaryExist(pathNoExtension)) {
      continue;
    }

    try {
      final dict = Mdict(path: pathNoExtension);
      await dict.add();
      talker.info("Added dictionary: $pathNoExtension");
    } catch (e) {
      if (context.mounted) {
        ToastService.show(AppLocalizations.of(context)!.notSupport, context,
            type: ToastType.error);
        talker.error("Failed to add dictionary: $pathNoExtension, error: $e", e,
            StackTrace.current);
      }
    }

    // Why? Don't know. Strange!
    continue;
  }

  if (context.mounted) {
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
    await reader.initDict();

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

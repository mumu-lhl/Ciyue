import "dart:async";
import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:ciyue/ui/core/loading_dialog.dart";
import "package:dict_reader/dict_reader.dart";
import "package:drift/drift.dart";
import "package:file_selector/file_selector.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";
import "package:provider/provider.dart";

final dictManager = DictManager();

class MddResourceData {
  final RecordOffsetInfo offsetInfo;
  final int? part;

  const MddResourceData({required this.offsetInfo, this.part});

  String get key => offsetInfo.keyText;
  int get blockOffset => offsetInfo.recordBlockOffset;
  int get startOffset => offsetInfo.startOffset;
  int get endOffset => offsetInfo.endOffset;
  int get compressedSize => offsetInfo.compressedSize;
}

class DictManager {
  final Map<int, Mdict> dicts = {};
  List<DictGroupData> groups = [];
  List<int> dictIds = [];
  int groupId = 0;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool get isEmpty => dicts.isEmpty;

  /// Registers a dictionary after its small header-only initialization.
  ///
  /// The expensive key/record/resource loading is started in the background.
  /// Callers that need the dictionary to be ready should await the individual
  /// [Mdict.waitForLoading] call instead.
  Future<void> add(int id, String path) async {
    final dict = Mdict(path: path);
    try {
      await dict.initMetadata();
    } catch (e, stackTrace) {
      try {
        await dict.close();
      } catch (_) {
        // Preserve the initialization error.
      }
      Error.throwWithStackTrace(e, stackTrace);
    }

    dicts[id] = dict;
    final initialization = dict.init();
    unawaited(_observeInitialization(id, path, initialization));
  }

  Future<void> _observeInitialization(
    int id,
    String path,
    Future<void> initialization,
  ) async {
    try {
      await initialization;
    } catch (e, stackTrace) {
      talker.error(
        "Failed to initialize dictionary $id ($path): $e",
        e,
        stackTrace,
      );
    }
  }

  Future<void> _clear() async {
    await Future.wait([for (final id in dictIds) close(id)]);
  }

  Future<void> close(int id) async {
    final dict = dicts[id];
    if (dict == null) {
      return;
    }

    // A dictionary may still be loading in the background. Do not make group
    // switching wait for the complete index scan; close it when loading ends.
    await dict.close(waitForLoading: false);
    dicts.remove(id);
  }

  bool contain(int id) => dicts.keys.contains(id);

  Future<void> setCurrentGroup(int id) async {
    _isLoading = true;

    try {
      await _clear();

      groupId = id;
      dictIds = await dictGroupDao.getDictIds(id);
      final paths = await Future.wait([
        for (final dictId in dictIds) dictionaryListDao.getPath(dictId),
      ]);

      final added = await Future.wait([
        for (var i = 0; i < paths.length; i++) _tryAdd(dictIds[i], paths[i]),
      ]);
      final toRemove = <int>[];
      for (var i = 0; i < added.length; i++) {
        if (!added[i]) {
          await dictionaryListDao.remove(paths[i]);
          toRemove.add(i);
        }
      }

      for (final i in toRemove.reversed) {
        final dictId = dictIds.removeAt(i);
        final databasePath = join(
          (await databaseDirectory()).path,
          "dictionary_$dictId.sqlite",
        );
        final file = File(databasePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      if (toRemove.isNotEmpty) {
        await dictGroupDao.updateDictIds(groupId, dictIds);
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<bool> _tryAdd(int id, String path) async {
    try {
      await add(id, path);
      return true;
    } catch (e, stackTrace) {
      talker.error("Failed to add dictionary $id ($path): $e", e, stackTrace);
      return false;
    }
  }
}

class Mdict implements DictionarySource {
  @override
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
  static const _maxLinkResolutionDepth = 8;

  bool isLoading = true;
  Future<void>? _metadataInitialization;
  Future<void>? _initialization;
  Future<void>? _closeFuture;
  bool _readerInitialized = false;
  bool _serverInitialized = false;
  Object? _initializationError;

  bool get isReady =>
      _initialization != null && !isLoading && _initializationError == null;

  Mdict({required this.path});

  Future<void> initMetadata() =>
      _metadataInitialization ??= _initializeMetadata();

  Future<void> _initializeMetadata() async {
    id = await dictionaryListDao.getId(path);
    type = await dictionaryListDao.getType(id);

    if (!_readerInitialized) {
      reader = DictReader("$path.mdx");
      _readerInitialized = true;
    }
    await reader.initDict(readKeys: false, readRecordBlockInfo: false);
    title = reader.header["Title"] ?? basename(path);
  }

  Future<void> add() async {
    reader = DictReader("$path.mdx");
    _readerInitialized = true;
    await reader.initDict(readKeys: false, readRecordBlockInfo: false);

    title = reader.header["Title"] ?? basename(path);

    await dictionaryListDao.add(path, title);
    isLoading = false;
  }

  Future<void> close({bool waitForLoading = true}) {
    final existing = _closeFuture;
    if (existing != null) {
      return waitForLoading ? existing : Future<void>.value();
    }

    final closeFuture = _closeAfterInitialization();
    _closeFuture = closeFuture;

    // Group changes should not wait for a background dictionary scan. The
    // cleanup future keeps the reader open until that scan has finished.
    if (!waitForLoading && isLoading) {
      unawaited(_observeClose(closeFuture));
      return Future<void>.value();
    }
    return closeFuture;
  }

  Future<void> _observeClose(Future<void> closing) async {
    try {
      await closing;
    } catch (e, stackTrace) {
      talker.error("Failed to close dictionary $path: $e", e, stackTrace);
    }
  }

  Future<void> _closeAfterInitialization() async {
    final initialization = _initialization ?? _metadataInitialization;
    if (initialization != null) {
      try {
        await initialization;
      } catch (_) {
        // Close partially initialized readers even when initialization failed.
      }
    }

    if (_serverInitialized) {
      try {
        await server?.close(force: true);
      } catch (_) {
        // Continue closing dictionary readers.
      }
    }

    final readers = <Future<void>>[];
    if (_readerInitialized) {
      readers.add(reader.close());
    }
    readers.addAll(
      readerResources.map((readerResource) => readerResource.close()),
    );
    await Future.wait(readers);
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

      try {
        final cacheData = await reader.exportCacheAsString();
        await cacheFile.writeAsString(cacheData, flush: true);
      } catch (e, stackTrace) {
        talker.error("Failed to save cache for $id ($type): $e", e, stackTrace);
      }
    };
  }

  Future<bool> hitCache(int id, String type, DictReader reader) async {
    final cacheFileName = "dict_reader_${id.toString()}_$type.cache";
    final cacheDir = await getApplicationCacheDirectory();
    final cacheFile = File(join(cacheDir.path, cacheFileName));

    if (!await cacheFile.exists()) {
      return false;
    }

    try {
      final cache = await cacheFile.readAsString();
      await reader.importCacheFromString(cache);
      return true;
    } catch (e, stackTrace) {
      talker.error("Failed to import cache for $id ($type): $e", e, stackTrace);
      try {
        await cacheFile.delete();
      } catch (_) {
        // The cache is optional; continue with a full dictionary scan.
      }
      return false;
    }
  }

  Future<void> _getTitle() async {
    final titleInDatabase = await dictionaryListDao.getTitle(id);
    final title = HtmlUnescape().convert(
      titleInDatabase ?? reader.header["Title"] ?? basename(path),
    );

    if (title == "") {
      this.title = basename(path);
    } else {
      this.title = title;
    }
  }

  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      await initMetadata();
      await initDictReaders();

      final fontPath = await dictionaryListDao.getFontPath(id);
      await customFont(fontPath);

      await _getTitle();

      await _checkResources();

      if (Platform.isWindows || Platform.isLinux) {
        await _startServer();
      }
    } catch (e) {
      _initializationError = e;
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  Future<void> initDictReaders() async {
    if (!await hitCache(id, "mdx", reader)) {
      reader.setOnRecordBlockInfoRead(saveCache(id, "mdx", reader));
      await reader.initDict(readHeader: false);
    }

    Future<void> loadMddReader(File file, String cacheType) async {
      final resourceReader = DictReader(file.path);
      try {
        if (!await hitCache(id, cacheType, resourceReader)) {
          resourceReader.setOnRecordBlockInfoRead(
            saveCache(id, cacheType, resourceReader),
          );
          await resourceReader.initDict();
        } else {
          // importCache opens the file in current dict_reader versions. Keep
          // this no-op initialization for compatibility with older versions.
          await resourceReader.initDict(
            readKeys: false,
            readRecordBlockInfo: false,
          );
        }
        readerResources.add(resourceReader);
      } catch (_) {
        await resourceReader.close();
        rethrow;
      }
    }

    final mddFile = File("$path.mdd");
    if (await mddFile.exists()) {
      await loadMddReader(mddFile, "mdd");
    }

    for (var i = 1; ; i++) {
      final mddFile = File("$path.$i.mdd");
      if (!await mddFile.exists()) {
        break;
      }
      await loadMddReader(mddFile, "$i.mdd");
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
    _readerInitialized = true;

    try {
      if (await hitCache(id, "mdx", reader)) {
        await reader.initDict(readKeys: false, readRecordBlockInfo: false);
      } else {
        await reader.initDict(readRecordBlockInfo: false);
      }

      await _getTitle();
      await _checkResources();
      entriesTotal = reader.numEntries;
    } finally {
      isLoading = false;
    }
  }

  Future<void> waitForLoading() async {
    final initialization = _initialization;
    if (initialization != null) {
      await initialization;
      return;
    }

    while (isLoading) {
      await Future.delayed(Duration(milliseconds: 40));
    }
  }

  Future<List<int>?> _readResourceDesktop(String filename) async {
    if (filename == "favicon.ico") {
      return null;
    }

    if (filename == fontName && fontPath != null) {
      final file = File(fontPath!);
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
            final info = result.offsetInfo;
            try {
              if (result.part == null) {
                data = await readerResources[0].readOneMdd(info) as Uint8List;
              } else {
                data = await readerResources[result.part!].readOneMdd(
                  info,
                ) as Uint8List;
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

  @override
  Future<String?> resolveExactKey(String word) async {
    await waitForLoading();

    if (reader.exist(word)) {
      return word;
    }

    final lowerCaseWord = word.toLowerCase();
    if (reader.exist(lowerCaseWord)) {
      return lowerCaseWord;
    }

    return null;
  }

  Future<DictionaryEntryData?> readExactEntry(String word) {
    return _readExactEntry(word, visitedHeadwords: const {}, depth: 0);
  }

  Future<DictionaryEntryData?> _readExactEntry(
    String word, {
    required Set<String> visitedHeadwords,
    required int depth,
  }) async {
    final headword = await resolveExactKey(word);
    if (headword == null) {
      return null;
    }

    final data = await locateAll(headword);
    final contents = <String>[];
    for (final info in data) {
      contents.add(await reader.readOneMdx(info));
    }

    final pathHeadwords = {...visitedHeadwords, headword};
    final resolvedContents = <String>[];
    for (final content in contents) {
      final linkedWord = _linkedWord(content);
      if (linkedWord == null || depth >= _maxLinkResolutionDepth) {
        resolvedContents.add(content);
        continue;
      }

      final linkedHeadword = await resolveExactKey(linkedWord);
      if (linkedHeadword == null || pathHeadwords.contains(linkedHeadword)) {
        resolvedContents.add(content);
        continue;
      }

      final linkedEntry = await _readExactEntry(
        linkedHeadword,
        visitedHeadwords: pathHeadwords,
        depth: depth + 1,
      );
      resolvedContents.add(linkedEntry?.content ?? content);
    }

    return DictionaryEntryData(
      headword: headword,
      content: resolvedContents.join(),
    );
  }

  String? _linkedWord(String content) {
    const prefix = "@@@LINK=";
    final trimmed = content.replaceFirst("\uFEFF", "").trim();
    if (!trimmed.startsWith(prefix)) {
      return null;
    }

    final linkedWord = trimmed.substring(prefix.length).trim();
    return linkedWord.isEmpty ? null : linkedWord;
  }

  @override
  Future<List<DictionaryEntryData>> readExactEntries(
    Iterable<String> words,
  ) async {
    final entries = <DictionaryEntryData>[];
    final seenHeadwords = <String>{};

    for (final word in words) {
      final entry = await readExactEntry(word);
      if (entry != null && seenHeadwords.add(entry.headword)) {
        entries.add(entry);
      }
    }

    return entries;
  }

  Future<String> readWord(String word) async {
    final entry = await readExactEntry(word);
    if (entry == null) {
      throw Exception("Word not found: $word");
    }

    return wrapContentWithResources(entry.content);
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

  Future<void> removeDictionary({int? dictionaryId}) async {
    final removeId = dictionaryId ?? id;
    final removeType = dictionaryId == null
        ? type
        : await dictionaryListDao.getType(removeId);

    if (removeType == 0) {
      final databasePath = join(
        (await databaseDirectory()).path,
        "dictionary_$removeId.sqlite",
      );
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

      for (var i = 1; ; i++) {
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

  @override
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
    return await resolveExactKey(word) != null;
  }

  Future<List<MddResourceData>> readResource(String key) async {
    final resourceData = <MddResourceData>[];

    final slashKey = key.replaceAll("\\", "/");
    final backslashKey = key.replaceAll("/", "\\");
    final keysToTry = <String>{
      key,
      slashKey,
      backslashKey,
      if (key.startsWith("/") || key.startsWith("\\")) key.substring(1),
      if (slashKey.startsWith("/")) slashKey.substring(1),
      if (backslashKey.startsWith("\\")) backslashKey.substring(1),
      if (!key.startsWith("/") && !key.startsWith("\\")) "/$key",
      if (!slashKey.startsWith("/")) "/$slashKey",
      if (!backslashKey.startsWith("\\")) "\\$backslashKey",
    }.toList();

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

      resourceData.add(
        MddResourceData(offsetInfo: offsetInfo, part: part == -1 ? null : part),
      );
    }

    return resourceData;
  }

  Future<void> _startServer() async {
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _serverInitialized = true;
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
      if (_serverInitialized) {
        await server?.close(force: true);
      }
    }
  }
}

Future<void> selectMdx(
  BuildContext context,
  List<String> paths, {
  bool closeLoadingWhenEmpty = false,
}) async {
  if (paths.isEmpty) {
    if (closeLoadingWhenEmpty && context.mounted) {
      context.pop();
    }
    if (context.mounted) {
      ToastService.show(
        AppLocalizations.of(context)!.noDictionariesFound,
        context,
        type: ToastType.info,
      );
    }
    return;
  }

  for (final path in paths) {
    final pathNoExtension = setExtension(path, "");

    if (await dictionaryListDao.dictionaryExist(pathNoExtension)) {
      continue;
    }

    final dict = Mdict(path: pathNoExtension);
    try {
      await dict.add();
      talker.info("Added dictionary: $pathNoExtension");
    } catch (e) {
      if (context.mounted) {
        ToastService.show(
          AppLocalizations.of(context)!.notSupport,
          context,
          type: ToastType.error,
        );
        talker.error(
          "Failed to add dictionary: $pathNoExtension, error: $e",
          e,
          StackTrace.current,
        );
      }
    } finally {
      await dict.close();
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
    try {
      await reader.initDict();

      int? mddAudioListId;
      if (context.mounted) {
        final title =
            reader.header["Title"] ?? setExtension(basename(path), "");
        mddAudioListId = await context.read<AudioModel>().addMddAudio(
          path,
          title,
        );
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
                .addingResource(info.keyText),
          );
          loadingCount = 0;
        }

        final data = MddAudioResourceCompanion(
          key: Value(info.keyText),
          blockOffset: Value(info.recordBlockOffset),
          startOffset: Value(info.startOffset),
          endOffset: Value(info.endOffset),
          compressedSize: Value(info.compressedSize),
          mddAudioListId: Value(mddAudioListId!),
        );
        resources.add(data);

        number++;
        loadingCount++;
      }

      if (number > 0) {
        await mddAudioResourceDao.add(resources);
      }
    } finally {
      await reader.close();
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
  Directory startDir,
  List<String> output,
  String extension,
) async {
  if (!await startDir.exists()) {
    return;
  }

  final expectedExtension = extension.startsWith(".")
      ? extension.toLowerCase()
      : ".${extension.toLowerCase()}";

  try {
    await for (final entity in startDir.list(followLinks: false)) {
      if (entity is File) {
        if (entity.path.toLowerCase().endsWith(expectedExtension)) {
          output.add(entity.path);
        }
      } else if (entity is Directory) {
        await findAllFileByExtension(entity, output, extension);
      }
    }
  } on FileSystemException {
    // A single unreadable directory should not prevent the remaining folders
    // from being scanned.
  }
}

String _normalizeScannedPath(String path) {
  final normalizedPath = normalize(absolute(path));
  return Platform.isWindows ? normalizedPath.toLowerCase() : normalizedPath;
}

Future<List<String>> findMdxFilesInDirectories(
  Iterable<String> directories,
) async {
  final mdxFiles = <String>[];
  final seen = <String>{};

  for (final directoryPath in directories) {
    final filesInDirectory = <String>[];
    await findAllFileByExtension(
      Directory(directoryPath),
      filesInDirectory,
      "mdx",
    );

    for (final filePath in filesInDirectory) {
      if (seen.add(_normalizeScannedPath(filePath))) {
        mdxFiles.add(filePath);
      }
    }
  }

  mdxFiles.sort();
  return mdxFiles;
}

Future<List<String>> findMdxFilesOnAndroid(String? directory) async {
  final documentsDir = Directory(
    directory ??
        join((await getApplicationSupportDirectory()).path, "dictionaries"),
  );
  return findMdxFilesInDirectories([documentsDir.path]);
}

Future<void> selectMdxFromDirectoriesOnDesktop(BuildContext context) async {
  final selectedPaths = await getDirectoryPaths();
  final directories = selectedPaths
      .where((path) => path != null && path.isNotEmpty)
      .cast<String>()
      .toList();

  if (directories.isEmpty || !context.mounted) {
    return;
  }

  showLoadingDialog(context, text: AppLocalizations.of(context)!.loading);
  final mdxFiles = await findMdxFilesInDirectories(directories);

  if (context.mounted) {
    await selectMdx(context, mdxFiles, closeLoadingWhenEmpty: true);
  }
}

import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:isolate";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary_import_failure.dart";
import "package:ciyue/repositories/stardict.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/services/zip_archive_reader.dart";
import "package:ciyue/utils.dart";
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
import "package:ciyue/core/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

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
  final Map<int, LoadedDictionary> dicts = {};
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
  /// [LoadedDictionary.waitForLoading] call instead.
  Future<void> add(int id, String path) async {
    final type = await dictionaryListDao.getType(id);
    final LoadedDictionary dict = DictionaryType.isStardict(type)
        ? Stardict(path: path)
        : Mdict(path: path);
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

      // Adding a dictionary only reads its header, so one the reader cannot
      // decode — an LZO-compressed MDX — is added first and fails here, in the
      // background. Without this the entry just sits there with no headwords
      // and no reason, which is the one case where the user can do something:
      // convert the file and import it again. The rest stay in the log.
      if (classifyDictionaryImportFailure(e) !=
          DictionaryImportFailure.unsupportedCompression) {
        return;
      }

      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      await ToastService.show(
        AppLocalizations.of(context)!
            .dictionaryUnsupportedCompression(1, basename(path)),
        context,
        type: ToastType.error,
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
    if (id == groupId) return;

    _isLoading = true;

    try {
      await _clear();

      groupId = id;
      dictIds = await dictGroupDao.getDictIds(id);
      final rawPaths = await Future.wait([
        for (final dictId in dictIds) dictionaryListDao.getPath(dictId),
      ]);

      final validDictIds = <int>[];
      final validPaths = <String>[];
      var hasMissingDict = false;

      for (var i = 0; i < dictIds.length; i++) {
        final path = rawPaths[i];
        if (path != null) {
          validDictIds.add(dictIds[i]);
          validPaths.add(path);
        } else {
          hasMissingDict = true;
        }
      }

      dictIds = validDictIds;

      final added = await Future.wait([
        for (var i = 0; i < validPaths.length; i++)
          _tryAdd(validDictIds[i], validPaths[i]),
      ]);
      final toRemove = <int>[];
      for (var i = 0; i < added.length; i++) {
        if (!added[i]) {
          await dictionaryListDao.remove(validPaths[i]);
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

      if (toRemove.isNotEmpty || hasMissingDict) {
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

/// The plain file name of an external resource that may override the copy
/// packed inside a dictionary's .mdd, or null when [resourcePath] is not
/// overridable. Only `.css` / `.js` can be overridden (GoldenDict behavior:
/// an external file wins over the packaged one), and only as a flat file
/// name — resource paths arrive from URLs, so anything containing a path
/// separator or a `..` segment never reaches the file system through here.
/// A single leading slash or backslash is stripped first: dictionary HTML
/// links and MDict keys sometimes carry one (`\daijirin2.css`).
String? externalOverrideFileName(String resourcePath) {
  var name = resourcePath;
  while (name.startsWith("/") || name.startsWith("\\")) {
    name = name.substring(1);
  }
  if (name.isEmpty || name.contains("/") || name.contains("\\")) {
    return null;
  }
  if (name == "." || name.contains("..")) {
    return null;
  }
  final lower = name.toLowerCase();
  if (!lower.endsWith(".css") && !lower.endsWith(".js")) {
    return null;
  }
  return name;
}

/// Bytes of the external override for [resourcePath] sitting next to the
/// dictionary at [dictPath], or null when there is none (not an overridable
/// resource, or no such file). Shared by the Android asset loader and the
/// desktop resource server so their precedence cannot drift apart.
Future<Uint8List?> readExternalResourceOverride(
  String dictPath,
  String resourcePath,
) async {
  final name = externalOverrideFileName(resourcePath);
  if (name == null) {
    return null;
  }
  final file = File("${dirname(dictPath)}/$name");
  if (!await file.exists()) {
    return null;
  }
  return file.readAsBytes();
}

class Mdict implements LoadedDictionary {
  @override
  late int id;
  @override
  final String path;
  String? fontName;
  String? fontPath;
  late final DictReader reader;
  List<DictReader> readerResources = [];
  @override
  late String title;
  @override
  late final int entriesTotal;

  @override
  late final int type;

  bool hasCss = false;
  bool hasJs = false;

  late HttpServer? server;
  @override
  int port = 0;

  static const maxBatchSize = 50000;
  static const maxLoadingCount = 5000;

  bool _isLoading = true;
  @override
  bool get isLoading => _isLoading;
  set isLoading(bool value) {
    _isLoading = value;
    if (!value) {
      // Wake up any waitForLoading callers without polling.
      _loadingCompleter?.complete();
      _loadingCompleter = null;
    }
  }

  /// Cache of successful resource key resolutions: requested key ->
  /// (found key, reader index). MDD files use inconsistent key formats, but
  /// for a given dictionary the working variant is stable, so cache it to
  /// avoid trying up to 9 variants x N readers on every lookup.
  final Map<String, ({String foundKey, int readerIndex})> _resourceKeyCache =
      {};

  /// Zip archives holding this dictionary's companion resources (e.g.
  /// pronunciation audio), mirroring the `.mdd` / `.N.mdd` scheme:
  /// `<path>.zip`, `<path>.1.zip`, and so on. Readers are opened lazily
  /// and cached; a missing archive ends the sequence, as with `.mdd`
  /// parts.
  final Map<String, ZipArchiveReader> _zipReaders = {};

  Iterable<String> get _zipArchivePaths sync* {
    yield "$path.zip";
    for (var i = 1; ; i++) {
      yield "$path.$i.zip";
    }
  }

  ZipArchiveReader? _zipReaderFor(String archivePath) {
    final cached = _zipReaders[archivePath];
    if (cached != null) return cached;
    final file = File(archivePath);
    if (!file.existsSync()) return null;
    final reader = ZipArchiveReader(file);
    _zipReaders[archivePath] = reader;
    return reader;
  }

  /// Reads one companion resource from a `<path>.zip` / `<path>.N.zip`
  /// audio pack, or null when no pack contains [filename]. Callers consult
  /// the `.mdd` readers and loose directory files first; this is the last
  /// fallback.
  Future<Uint8List?> readZipResource(String filename) async {
    for (final archivePath in _zipArchivePaths) {
      final reader = _zipReaderFor(archivePath);
      if (reader == null) break;
      final data = await reader.readEntry(filename);
      if (data != null) return data;
    }
    return null;
  }

  /// Whether any zip audio pack contains [filename], without inflating it.
  Future<bool> containsZipResource(String filename) async {
    for (final archivePath in _zipArchivePaths) {
      final reader = _zipReaderFor(archivePath);
      if (reader == null) break;
      if (await reader.containsEntry(filename)) return true;
    }
    return false;
  }

  Completer<void>? _loadingCompleter;
  Future<void>? _metadataInitialization;
  Future<void>? _initialization;
  Future<void>? _closeFuture;
  bool _readerInitialized = false;
  bool _serverInitialized = false;
  Object? _initializationError;

  @override
  bool get isReady =>
      _initialization != null && !isLoading && _initializationError == null;

  Mdict({required this.path});

  @override
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

  @override
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
    for (final reader in _zipReaders.values) {
      reader.close();
    }
    _zipReaders.clear();
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

  /// The self-built index (`.cidx`) for one dictionary reader, in the
  /// cache directory (it is rebuildable data, so the standard cache
  /// semantics apply: the system may clear it, and a clear simply
  /// triggers a rescan).
  Future<File> _readerCacheFile(int id, String type) async {
    final cacheFileName = "dict_reader_${id.toString()}_$type.cidx";
    final cacheDir = await getApplicationCacheDirectory();
    return File(join(cacheDir.path, cacheFileName));
  }

  void Function() saveCache(int id, String type, DictReader reader) {
    return () async {
      final cacheFile = await _readerCacheFile(id, type);

      if (await cacheFile.exists()) {
        return;
      }

      try {
        final cacheData = await reader.exportCidx();
        await cacheFile.writeAsBytes(cacheData, flush: true);
        // The old JSON cache is gone for good: drop its file (tens of MB
        // per dictionary) instead of leaving it orphaned.
        try {
          final legacy = File(
            "${cacheFile.path.substring(0, cacheFile.path.length - 5)}.cache",
          );
          if (await legacy.exists()) {
            await legacy.delete();
          }
        } catch (_) {}
      } catch (e, stackTrace) {
        talker.error("Failed to save cache for $id ($type): $e", e, stackTrace);
      }
    };
  }

  Future<bool> hitCache(int id, String type, DictReader reader) async {
    final cacheFile = await _readerCacheFile(id, type);

    if (!await cacheFile.exists()) {
      return false;
    }

    try {
      // Read the index file off the UI isolate to avoid blocking the UI
      // thread on large file IO.
      // Capture the path as a String: File objects hold native resources
      // and cannot be sent across isolates.
      final cachePath = cacheFile.path;
      final cache = await Isolate.run(() => File(cachePath).readAsBytes());
      await reader.importCidx(cache);
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

  @override
  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      await initMetadata();
      await initDictReaders();

      final fontPath = await dictionaryListDao.getFontPath(id);
      await customFont(fontPath);

      await _getTitle();

      await _checkResources();

      if (isDesktop()) {
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
          // importCidx opens the file in current dict_reader versions. Keep
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

    // Check zip audio packs.
    if (!hasCss) {
      hasCss = await containsZipResource(cssName);
    }
    if (!hasJs) {
      hasJs = await containsZipResource(jsName);
    }
  }

  @override
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

  @override
  Future<void> waitForLoading() async {
    final initialization = _initialization ?? _metadataInitialization;
    if (initialization != null) {
      await initialization;
      return;
    }

    if (!isLoading) {
      return;
    }
    // No polling: the isLoading setter completes this when loading finishes.
    // The check-then-create is race-free: no await runs in between, so the
    // setter cannot complete a completer we haven't created yet.
    await (_loadingCompleter ??= Completer<void>()).future;
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
        // Find resource under directory if no mdd, else in a zip pack.
        data = await _readLooseResourceFile(filename);
      } else {
        // An external .css/.js next to the dictionary overrides the copy
        // packed inside the .mdd (see readExternalResourceOverride).
        final override = await readExternalResourceOverride(path, filename);
        if (override != null) {
          return override;
        }
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
          // A failed mdd lookup falls through to the loose file / zip.
        }
        data ??= await _readLooseResourceFile(filename);
      }
      return data;
    } catch (e) {
      return null;
    }
  }

  /// A companion file kept loose next to the dictionary, or packed in a
  /// zip audio pack. Returns null when it exists in neither place.
  Future<Uint8List?> _readLooseResourceFile(String filename) async {
    try {
      return await File("${dirname(path)}/$filename").readAsBytes();
    } catch (_) {
      return readZipResource(filename);
    }
  }

  @override
  Future<String?> resolveExactKey(String word) async {
    final resolved = await resolveKeys([word]);
    return resolved[word];
  }

  @override
  Future<Map<String, String>> resolveKeys(Iterable<String> words) async {
    await waitForLoading();

    // Exact spelling first, then the case/kana variants of it. Only the query
    // was lower-cased before, which reached a lower-case headword from an
    // upper-case query but never the other way round: `nahida` could not find
    // `Nahida`.
    final resolved = <String, String>{};
    for (final word in words) {
      for (final candidate in lookupVariants(word)) {
        if (reader.exist(candidate)) {
          resolved[word] = candidate;
          break;
        }
      }
    }
    return resolved;
  }

  Future<DictionaryEntryData?> readExactEntry(String word) {
    return _readExactEntry(word, const {});
  }

  Future<DictionaryEntryData?> _readExactEntry(
    String word,
    Set<String> visitedHeadwords,
  ) async {
    final headword = await resolveExactKey(word);
    if (headword == null) {
      return null;
    }

    final data = await locateAll(headword);
    // Read records concurrently: each read is an independent random disk
    // access + decompression, and the reader's record-block cache is safe
    // for concurrent use.
    final contents = await Future.wait(data.map(reader.readOneMdx));

    final pathHeadwords = {...visitedHeadwords, headword};
    final resolvedContents = <String>[];
    for (final content in contents) {
      final linkedWords = _linkedWords(content);
      if (linkedWords.isEmpty) {
        resolvedContents.add(content);
        continue;
      }

      var resolved = false;
      for (final linkedWord in linkedWords) {
        final linkedHeadword = await resolveExactKey(linkedWord);
        if (linkedHeadword == null || pathHeadwords.contains(linkedHeadword)) {
          continue;
        }

        final linkedEntry = await _readExactEntry(
          linkedHeadword,
          pathHeadwords,
        );
        if (linkedEntry != null) {
          resolvedContents.add(linkedEntry.content);
          resolved = true;
        }
      }

      // Keep malformed or broken redirects visible instead of making a
      // dictionary lookup fail altogether.
      if (!resolved) {
        resolvedContents.add(content);
      }
    }

    return DictionaryEntryData(
      headword: headword,
      content: resolvedContents.join(),
    );
  }

  List<String> _linkedWords(String content) {
    const prefix = "@@@LINK=";
    // Fast path: most entries are not links. Avoid copying MB-sized strings
    // with replaceAll when the prefix can't be at the start (after junk).
    final prefixIndex = content.indexOf(prefix);
    if (prefixIndex != -1) {
      var onlyJunkBefore = true;
      for (var i = 0; i < prefixIndex; i++) {
        final unit = content.codeUnitAt(i);
        if (unit != 0xFEFF &&
            unit != 0x00 &&
            unit != 0x20 &&
            unit != 0x09 &&
            unit != 0x0A &&
            unit != 0x0D) {
          onlyJunkBefore = false;
          break;
        }
      }
      if (!onlyJunkBefore) {
        return const [];
      }
    } else {
      return const [];
    }

    final trimmed = content
        .replaceAll("\uFEFF", "")
        .replaceAll("\u0000", "")
        .trim();
    if (!trimmed.startsWith(prefix)) {
      return const [];
    }

    return trimmed
        .split(prefix)
        .skip(1)
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
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

  @override
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

  @override
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
      // The cache file only exists if the dictionary was ever enabled.
      // Deleting a never-enabled dictionary would throw FileSystemException
      // and leave a ghost row in the UI list.
      if (await file.exists()) {
        await file.delete();
      }
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

  @override
  void setDefaultTitle() {
    title = HtmlUnescape().convert(reader.header["Title"] ?? basename(path));
  }

  @override
  String get description => reader.header["Description"] ?? "";

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

    // Fast path: use cached key mapping if we've resolved this key before.
    final cached = _resourceKeyCache[key];
    if (cached != null && cached.readerIndex < readerResources.length) {
      final readerResource = readerResources[cached.readerIndex];
      final offsetInfo = await readerResource.locate(cached.foundKey);
      if (offsetInfo != null) {
        resourceData.add(
          MddResourceData(offsetInfo: offsetInfo, part: cached.readerIndex),
        );
        return resourceData;
      }
      // Cache entry went stale; fall through to full lookup.
      _resourceKeyCache.remove(key);
    }

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

    for (var i = 0; i < readerResources.length; i++) {
      final readerResource = readerResources[i];
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

      // Cache the successful mapping for future lookups.
      _resourceKeyCache[key] = (foundKey: foundKey, readerIndex: i);

      final offsetInfo = await readerResource.locate(foundKey);

      if (offsetInfo == null) {
        continue;
      }

      resourceData.add(MddResourceData(offsetInfo: offsetInfo, part: i));
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
            ..headers.contentType = ContentType.parse(
              lookupMimeType(filename) ?? "application/octet-stream",
            )
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
  final failures = _ImportFailures();
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
      // Always log the original object: the toast only carries the category,
      // which is not enough to tell a corrupt file from a missing companion.
      talker.error(
        "Failed to add dictionary: $pathNoExtension, error: $e",
        e,
        StackTrace.current,
      );
      failures.add(
        classifyDictionaryImportFailure(e),
        name: basename(pathNoExtension),
      );
    } finally {
      await dict.close();
    }

    // Why? Don't know. Strange!
    continue;
  }

  if (context.mounted) {
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(manageDictionariesModelProvider).update();
    context.pop();
  }

  if (context.mounted) {
    await failures.report(context);
  }
}

/// The StarDict counterpart of [selectMdx]: same registration rules — the
/// extension-less path is the dictionary's identity, existing paths are
/// skipped, failures surface the same toast.
Future<void> selectStardict(
  BuildContext context,
  List<String> paths, {
  bool closeLoadingWhenEmpty = false,
}) async {
  final failures = _ImportFailures();
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

    final dict = Stardict(path: pathNoExtension);
    try {
      await dict.add();
      talker.info("Added dictionary: $pathNoExtension");
    } catch (e) {
      talker.error(
        "Failed to add dictionary: $pathNoExtension, error: $e",
        e,
        StackTrace.current,
      );
      failures.add(
        classifyDictionaryImportFailure(e),
        name: basename(pathNoExtension),
      );
    } finally {
      await dict.close();
    }
  }

  if (context.mounted) {
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(manageDictionariesModelProvider).update();
    context.pop();
  }

  if (context.mounted) {
    await failures.report(context);
  }
}

/// Counts a batch's import failures so the user gets one toast per category
/// instead of one per file.
class _ImportFailures {
  var unsupportedCompression = 0;
  var unknown = 0;

  /// The first file that could not be decoded. Named when it is the only one;
  /// with several, a name would be noise and the count says enough.
  String? firstUnsupportedName;

  void add(DictionaryImportFailure failure, {String? name}) {
    if (failure == DictionaryImportFailure.unsupportedCompression) {
      unsupportedCompression++;
      firstUnsupportedName ??= name;
    } else {
      unknown++;
    }
  }

  /// At most two toasts, the actionable one first. Awaited, because a second
  /// toast shown immediately would replace the first before it is read.
  Future<void> report(BuildContext context) async {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (unsupportedCompression > 0) {
      await ToastService.show(
        l10n.dictionaryUnsupportedCompression(
          unsupportedCompression,
          firstUnsupportedName ?? "",
        ),
        context,
        type: ToastType.error,
      );
      if (!context.mounted) return;
    }

    if (unknown > 0) {
      await ToastService.show(l10n.notSupport, context, type: ToastType.error);
    }
  }
}

Future<void> selectAudioMdd(BuildContext context, List<String> paths) async {
  var added = 0;
  var duplicates = 0;
  var failed = 0;
  for (final path in paths) {
    if (await mddAudioListDao.existMddAudio(path)) {
      duplicates++;
      continue;
    }

    final reader = DictReader(path);
    try {
      await reader.initDict();
      added++;

      int? mddAudioListId;
      if (context.mounted) {
        final title =
            reader.header["Title"] ?? setExtension(basename(path), "");
        mddAudioListId = await ProviderScope.containerOf(
          context,
          listen: false,
        ).read(audioModelProvider).addMddAudio(path, title);
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
    } catch (_) {
      // An unreadable file must not abort the remaining files or leave
      // the caller without feedback; it is reported after the loop.
      failed++;
    } finally {
      await reader.close();
    }
  }

  if (paths.isNotEmpty && context.mounted) {
    context.pop();
  }

  final toastContext = navigatorKey.currentContext;
  if (toastContext != null && toastContext.mounted) {
    final localizations = AppLocalizations.of(toastContext)!;
    if (failed > 0) {
      await ToastService.show(
        localizations.audioPackUnreadable,
        toastContext,
        type: ToastType.error,
      );
    } else if (added == 0 && duplicates > 0) {
      await ToastService.show(
        localizations.audioPackAlreadyAdded,
        toastContext,
        type: ToastType.info,
      );
    }
  }
}

/// Desktop file import for dictionaries: one picker accepting both MDict
/// (.mdx) and StarDict (.ifo) files, each routed to its format's add
/// pipeline.
Future<void> importDictionaryFilesOnDesktop(BuildContext context) async {
  final XTypeGroup typeGroup = XTypeGroup(
    label: "Dictionary File",
    extensions: <String>["mdx", "ifo"],
  );

  final files = await openFiles(acceptedTypeGroups: [typeGroup]);
  if (files.isEmpty) {
    return;
  }

  final paths = files.map((e) => e.path).toList();
  final mdxPaths = paths
      .where((path) => path.toLowerCase().endsWith(".mdx"))
      .toList();
  final ifoPaths = paths
      .where((path) => path.toLowerCase().endsWith(".ifo"))
      .toList();

  if (mdxPaths.isNotEmpty) {
    if (context.mounted) {
      showLoadingDialog(context, text: AppLocalizations.of(context)!.loading);
    }
    if (context.mounted) {
      await selectMdx(context, mdxPaths);
    }
  }

  if (ifoPaths.isNotEmpty && context.mounted) {
    showLoadingDialog(context, text: AppLocalizations.of(context)!.loading);
    if (context.mounted) {
      await selectStardict(context, ifoPaths);
    }
  }
}

Future<void> selectMddOnDesktop(BuildContext context) async {
  final XTypeGroup typeGroup = XTypeGroup(
    label: "MDD File",
    extensions: <String>["mdd"],
  );

  final files = await openFiles(acceptedTypeGroups: [typeGroup]);
  if (files.isEmpty) {
    return;
  }

  if (context.mounted) {
    showLoadingDialog(context, text: AppLocalizations.of(context)!.loading);
  }

  if (context.mounted) {
    await selectAudioMdd(context, files.map((e) => e.path).toList());
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

Future<List<String>> findStardictFilesInDirectories(
  Iterable<String> directories,
) async {
  final ifoFiles = <String>[];
  final seen = <String>{};

  for (final directoryPath in directories) {
    final filesInDirectory = <String>[];
    await findAllFileByExtension(
      Directory(directoryPath),
      filesInDirectory,
      "ifo",
    );

    for (final filePath in filesInDirectory) {
      if (seen.add(_normalizeScannedPath(filePath))) {
        ifoFiles.add(filePath);
      }
    }
  }

  ifoFiles.sort();
  return ifoFiles;
}

Future<List<String>> findStardictFilesOnAndroid(String? directory) async {
  final documentsDir = Directory(
    directory ??
        join((await getApplicationSupportDirectory()).path, "dictionaries"),
  );
  return findStardictFilesInDirectories([documentsDir.path]);
}

/// Desktop folder import: scans the picked directories for both MDict
/// (.mdx) and StarDict (.ifo) dictionaries and registers what it finds,
/// through each format's own add pipeline.
Future<void> importDictionariesFromDirectoriesOnDesktop(
  BuildContext context,
) async {
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
  final ifoFiles = await findStardictFilesInDirectories(directories);

  // The dialog above is closed by whichever add pipeline runs; when both
  // formats were found, it is shown again for the second one.
  final mdxHandled = mdxFiles.isNotEmpty || ifoFiles.isEmpty;
  if (mdxHandled && context.mounted) {
    await selectMdx(context, mdxFiles, closeLoadingWhenEmpty: true);
  }

  if (ifoFiles.isNotEmpty && context.mounted) {
    if (mdxHandled) {
      showLoadingDialog(context, text: AppLocalizations.of(context)!.loading);
    }
    await selectStardict(context, ifoFiles, closeLoadingWhenEmpty: true);
  }
}

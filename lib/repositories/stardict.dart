import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/services/zip_archive_reader.dart";
import "package:ciyue/services/stardict_html.dart";
import "package:ciyue/utils.dart";
import "package:dict_reader/dict_reader.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";

/// A StarDict dictionary, implementing the same loaded-dictionary surface
/// as [Mdict] so the manager, lookup and word display treat both formats
/// uniformly. [path] is the base path shared by the `.ifo`, `.idx` and
/// `.dict` (or `.dict.dz`) files, mirroring how an MDict dictionary is
/// identified by its extension-less path.
class Stardict implements LoadedDictionary {
  @override
  late int id;

  @override
  final String path;

  late final StarDictReader reader;
  bool _readerInitialized = false;

  @override
  late String title;

  @override
  late final int type;

  @override
  late final int entriesTotal;

  @override
  int port = 0;

  HttpServer? server;
  bool _serverInitialized = false;

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

  Completer<void>? _loadingCompleter;
  Future<void>? _metadataInitialization;
  Future<void>? _initialization;
  Future<void>? _closeFuture;
  Object? _initializationError;

  @override
  bool get isReady =>
      _initialization != null && !isLoading && _initializationError == null;

  Stardict({required this.path});

  void _ensureReader() {
    if (!_readerInitialized) {
      reader = StarDictReader(path);
      _readerInitialized = true;
    }
  }

  @override
  Future<void> initMetadata() =>
      _metadataInitialization ??= _initializeMetadata();

  Future<void> _initializeMetadata() async {
    id = await dictionaryListDao.getId(path);
    type = await dictionaryListDao.getType(id);
    _ensureReader();
    await reader.initMetadata();
    setDefaultTitle();
    entriesTotal = reader.wordCount;
  }

  /// Registers a new StarDict dictionary, mirroring Mdict.add: read the
  /// dictionary once, take the title from its own metadata, then store it.
  Future<void> add() async {
    _ensureReader();
    await reader.init();
    setDefaultTitle();
    await dictionaryListDao.add(path, title, type: DictionaryType.stardict);
    isLoading = false;
  }

  @override
  Future<void> initOnlyMetadata(int id) async {
    this.id = id;
    type = await dictionaryListDao.getType(id);
    _ensureReader();
    try {
      await reader.initMetadata();
      setDefaultTitle();
      entriesTotal = reader.wordCount;
    } finally {
      isLoading = false;
    }
  }

  @override
  void setDefaultTitle() {
    final name = _readerInitialized ? reader.bookName : "";
    title = name.isEmpty ? basename(path) : HtmlUnescape().convert(name);
  }

  @override
  String get description =>
      _readerInitialized ? (reader.ifo["description"] ?? "") : "";

  @override
  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      _ensureReader();
      await reader.init();
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
    await (_loadingCompleter ??= Completer<void>()).future;
  }

  @override
  Future<void> close({bool waitForLoading = true}) {
    final existing = _closeFuture;
    if (existing != null) {
      return waitForLoading ? existing : Future<void>.value();
    }

    final closeFuture = _closeAfterInitialization();
    _closeFuture = closeFuture;

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
        // Close partially initialized readers even when initialization
        // failed.
      }
    }

    if (_serverInitialized) {
      try {
        await server?.close(force: true);
      } catch (_) {
        // Continue closing the reader.
      }
    }

    _structuredFieldsCache.clear();
    for (final reader in _zipReaders.values) {
      reader?.close();
    }
    _zipReaders.clear();
    if (_readerInitialized) {
      await reader.close();
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

    // Try the exact spelling first, then the case/kana variants of it: a
    // lower-case query never reached a capitalised headword before, because
    // `resolveIndex` only lower-cases the query itself.
    final resolved = <String, String>{};
    for (final word in words) {
      for (final candidate in lookupVariants(word)) {
        final index = reader.resolveIndex(candidate);
        if (index != null) {
          resolved[word] = reader.wordAt(index);
          break;
        }
      }
    }
    return resolved;
  }

  @override
  Future<List<String>> search(String query) async {
    await waitForLoading();
    try {
      return reader.search(query);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<DictionaryEntryData>> readExactEntries(
    Iterable<String> words,
  ) async {
    final entries = <DictionaryEntryData>[];
    final seenHeadwords = <String>{};

    for (final word in words) {
      final entry = await _readEntry(word);
      if (entry != null && seenHeadwords.add(entry.headword)) {
        entries.add(entry);
      }
    }

    return entries;
  }

  /// Structured fields of recently read entries, keyed by headword. The
  /// word display uses them to render StarDict entries with native
  /// widgets instead of a WebView; [readExactEntries] fills the cache as
  /// a side effect of the normal lookup, so the fields on hand always
  /// match the entries the lookup reported. Bounded to the most recent
  /// [_structuredCacheLimit] headwords.
  final Map<String, List<StarDictField>> _structuredFieldsCache = {};

  static const int _structuredCacheLimit = 64;

  /// The structured fields of an entry read through [readExactEntries],
  /// or null when the entry has not been read (or was evicted).
  List<StarDictField>? structuredFieldsFor(String headword) =>
      _structuredFieldsCache[headword];

  /// The directory holding this dictionary's files; entry resources
  /// (images) live under its `res/` subdirectory.
  String get dictionaryDirectory => dirname(path);

  /// Zip archives holding this dictionary's resources, in lookup order,
  /// mirroring GoldenDict-ng: `res.zip`, `<name>.res.zip`, then
  /// `res/res.zip`.
  List<String> get _resourceArchivePaths {
    final directory = dictionaryDirectory;
    final base = basename(path);
    return [
      join(directory, "res.zip"),
      join(directory, "$base.res.zip"),
      join(directory, "res", "res.zip"),
    ];
  }

  final Map<String, ZipArchiveReader?> _zipReaders = {};

  ZipArchiveReader? _zipReaderFor(String archivePath) {
    if (_zipReaders.containsKey(archivePath)) return _zipReaders[archivePath];
    final file = File(archivePath);
    final reader = file.existsSync() ? ZipArchiveReader(file) : null;
    _zipReaders[archivePath] = reader;
    return reader;
  }

  /// Reads one resource file for an entry, from the `res/` directory first
  /// and then from a `res.zip` archive (see [_resourceArchivePaths]).
  /// [filename] is the path as referenced by the entry (`res/<file>` from
  /// WebView HTML, or the bare file name from native rendering); both
  /// spellings resolve. Returns null when the resource exists in neither
  /// place.
  Future<Uint8List?> readResourceFile(String filename) async {
    final fromDirectory = await _readLocalFile(filename);
    if (fromDirectory != null) return fromDirectory;
    if (!filename.startsWith("res/") && !filename.startsWith("res\\")) {
      final fromResDirectory = await _readLocalFile("res/$filename");
      if (fromResDirectory != null) return fromResDirectory;
    }
    var entryName = filename;
    if (entryName.startsWith("res/")) {
      entryName = entryName.substring("res/".length);
    } else if (entryName.startsWith("res\\")) {
      entryName = entryName.substring("res\\".length);
    }
    if (entryName.isEmpty) return null;
    for (final archivePath in _resourceArchivePaths) {
      final reader = _zipReaderFor(archivePath);
      if (reader == null) continue;
      final data =
          await reader.readEntry(entryName) ??
          await reader.readEntry("res/$entryName");
      if (data != null) return data;
    }
    return null;
  }

  void _cacheStructuredFields(String headword, List<StarDictField> fields) {
    _structuredFieldsCache[headword] = fields;
    while (_structuredFieldsCache.length > _structuredCacheLimit) {
      _structuredFieldsCache.remove(_structuredFieldsCache.keys.first);
    }
  }

  Future<DictionaryEntryData?> _readEntry(String word) async {
    await waitForLoading();
    final results = await reader.lookup(word);
    if (results.isEmpty) {
      return null;
    }
    // An entry counts as found only when it has something displayable: a
    // field that carries text. Entries holding only binary data (e.g. a
    // pronunciation blob) would otherwise render as a blank section.
    final displayable = results
        .where((entry) => entry.fields.any((field) => field.text != null))
        .toList();
    if (displayable.isEmpty) {
      return null;
    }
    // Every index entry under one headword belongs to the same displayed
    // entry (the HTML joins them), so cache their fields combined.
    _cacheStructuredFields(displayable.first.headword, [
      for (final entry in displayable) ...entry.fields,
    ]);
    final content = displayable
        .map((entry) => stardictEntryToHtml(entry.fields))
        .join();
    return DictionaryEntryData(
      headword: displayable.first.headword,
      content: content,
    );
  }

  Future<String> readWord(String word) async {
    final entry = await _readEntry(word);
    if (entry == null) {
      throw Exception("Word not found: $word");
    }
    return entry.content;
  }

  @override
  String wrapContentWithResources(String content) {
    // StarDict dictionaries have no companion stylesheet/script files to
    // prepend; entry HTML is self-contained.
    return content;
  }

  @override
  Future<void> removeDictionary({int? dictionaryId}) async {
    // StarDict dictionaries keep no per-dictionary cache database (that is
    // what the type check in Mdict.removeDictionary guards), so removal is
    // the registration plus, on Android's non-full flavor where the files
    // are app-owned copies, the dictionary's file set.
    await dictionaryListDao.remove(path);

    if (Platform.isAndroid && !isFullFlavor()) {
      for (final extension in [".ifo", ".idx", ".dict", ".dict.dz", ".syn"]) {
        final file = File("$path$extension");
        if (await file.exists()) {
          await file.delete();
        }
      }
      // A res/ folder may be shared by several dictionaries in the same
      // directory, so it is left in place.
    }
  }

  /// Serves the entry page and the dictionary's local files (such as the
  /// `res/` images XDXF and HTML entries reference) to the word display's
  /// WebView, mirroring the MDict content server.
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
          } catch (_) {
            request.response
              ..statusCode = HttpStatus.notFound
              ..close();
            return;
          }
        } else if (request.method == "GET" && request.uri.path != "/") {
          final filename = Uri.decodeComponent(request.uri.path.substring(1));
          final data = await readResourceFile(filename);
          if (data == null) {
            request.response
              ..statusCode = HttpStatus.notFound
              ..close();
            return;
          }
          request.response
            ..headers.contentType = ContentType.parse(
              lookupMimeType(filename) ?? "application/octet-stream",
            )
            ..add(data)
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

  /// Reads a file from the dictionary's own directory (including its
  /// `res/` subfolder). Paths escaping the directory are refused.
  Future<Uint8List?> _readLocalFile(String filename) async {
    if (filename == "favicon.ico") {
      return null;
    }
    final directory = normalize(dirname(path));
    final candidate = normalize(join(directory, filename));
    if (!candidate.startsWith("$directory${Platform.pathSeparator}")) {
      return null;
    }
    try {
      return await File(candidate).readAsBytes();
    } catch (_) {
      return null;
    }
  }
}

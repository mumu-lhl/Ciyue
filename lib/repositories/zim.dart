import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/services/media_tags.dart";
import "package:ciyue/utils.dart";
import "package:dict_reader/dict_reader.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

/// A ZIM archive (openZIM / Kiwix) dictionary, implementing [LoadedDictionary].
class Zim implements LoadedDictionary {
  @override
  late int id;

  @override
  final String path;

  late final ZimReader reader;
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

  Zim({required this.path});

  void _ensureReader() {
    if (!_readerInitialized) {
      reader = ZimReader("$path.zim");
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

  /// Registers a new ZIM dictionary into storage.
  Future<void> add() async {
    _ensureReader();
    await _initReaderWithCache();
    setDefaultTitle();
    await dictionaryListDao.add(path, title, type: DictionaryType.zim);
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
  String get description => _readerInitialized ? reader.description : "";

  @override
  Future<void> init() => _initialization ??= _initialize();

  Future<File?> _cacheFile() async {
    try {
      final dictId = id;
      final cacheDir = await getApplicationCacheDirectory();
      return File(join(cacheDir.path, "dict_reader_${dictId}_zim.cidx"));
    } catch (_) {
      return null;
    }
  }

  Future<void> _initReaderWithCache() async {
    final cache = await _cacheFile();
    if (cache != null && await cache.exists()) {
      try {
        final bytes = await cache.readAsBytes();
        await reader.importCidx(bytes);
        return;
      } catch (e) {
        talker.warning("Stale or invalid ZIM .cidx cache for $path: $e");
      }
    }

    await reader.init();
    if (cache != null) {
      // Cache the parsed index in the background for instant future cold starts
      unawaited(() async {
        try {
          final cidxBytes = await reader.exportCidx();
          await cache.writeAsBytes(cidxBytes, flush: true);
        } catch (e, st) {
          talker.error("Failed to write ZIM .cidx cache for $path", e, st);
        }
      }());
    }
  }

  Future<void> _initialize() async {
    try {
      _ensureReader();
      await _initReaderWithCache();
      setDefaultTitle();
      entriesTotal = reader.wordCount;
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
      return existing;
    }
    return _closeFuture = _close(waitForLoading: waitForLoading);
  }

  Future<void> _close({bool waitForLoading = true}) async {
    if (waitForLoading) {
      try {
        await this.waitForLoading();
      } catch (_) {}
    }

    if (_serverInitialized) {
      try {
        await server?.close(force: true);
      } catch (e) {
        talker.error("Error closing ZIM HTTP server on port $port: $e");
      } finally {
        server = null;
        _serverInitialized = false;
        port = 0;
      }
    }

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

    final resolved = <String, String>{};
    for (final word in words) {
      for (final candidate in lookupVariants(word)) {
        final index = reader.resolveIndex(candidate);
        if (index != null) {
          final entry = await reader.getEntry(index);
          if (entry.isRedirect) {
            final target = await reader.lookup(candidate);
            resolved[word] = target.isNotEmpty
                ? target.first.title
                : reader.wordAt(index);
          } else {
            resolved[word] = reader.wordAt(index);
          }
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
    await waitForLoading();
    final entries = <DictionaryEntryData>[];
    final seenHeadwords = <String>{};

    for (final word in words) {
      final results = await reader.lookup(word);
      if (results.isEmpty) continue;
      final entry = results.first;
      if (seenHeadwords.add(entry.title)) {
        final content = await entry.readText();
        entries.add(
          DictionaryEntryData(headword: entry.title, content: content),
        );
      }
    }

    return entries;
  }

  /// Reads a binary resource (image, font, audio, stylesheet) by path.
  Future<Uint8List?> readResourceFile(String filename) async {
    await waitForLoading();
    return reader.readDataByPath(filename);
  }

  @override
  String wrapContentWithResources(String content) {
    return rewriteMediaTags(content);
  }

  @override
  Future<void> removeDictionary({int? dictionaryId}) async {
    await dictionaryListDao.remove(path);
    try {
      final cache = await _cacheFile();
      if (cache != null && await cache.exists()) {
        await cache.delete();
      }
    } catch (_) {}

    if (Platform.isAndroid && !isFullFlavor()) {
      final file = File("$path.zim");
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Serves ZIM entry HTML and static assets (images, CSS, JS, audio, video)
  /// to the word display's WebView.
  Future<void> _startServer() async {
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _serverInitialized = true;
      port = server!.port;
      talker.info("ZIM HTTP server started on port $port");

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
          final entry = await reader.getEntryByPath(filename);
          if (entry == null) {
            request.response
              ..statusCode = HttpStatus.notFound
              ..close();
            return;
          }
          final mime = entry.mimeType;
          try {
            request.response.headers.contentType = ContentType.parse(
              mime.isNotEmpty
                  ? mime
                  : (lookupMimeType(filename) ?? "application/octet-stream"),
            );
          } catch (_) {
            request.response.headers.contentType = ContentType(
              "application",
              "octet-stream",
            );
          }

          final stream = await entry.openRead();
          await request.response.addStream(stream);
          await request.response.close();
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

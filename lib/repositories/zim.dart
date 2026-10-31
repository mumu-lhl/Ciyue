import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/base_dictionary.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/utils.dart";
import "package:dict_reader/dict_reader.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

/// A ZIM archive (openZIM / Kiwix) dictionary, implementing [LoadedDictionary].
class Zim extends BaseLoadedDictionary {
  late final ZimReader reader;
  bool _readerInitialized = false;

  Zim({required super.path});

  void _ensureReader() {
    if (!_readerInitialized) {
      reader = ZimReader("$path.zim");
      _readerInitialized = true;
    }
  }

  @override
  Future<void> initMetadata() =>
      metadataInitialization ??= _initializeMetadata();

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
  Future<void> init() => initialization ??= _initialize();

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
        await startDesktopServer(
          onReadResourceStream: (filename) async {
            final entry = await reader.getEntryByPath(filename);
            return entry?.openRead();
          },
          onReadResource: (filename) => reader.readDataByPath(filename),
        );
      }
    } catch (e) {
      initializationError = e;
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  @override
  Future<void> onClose() async {
    if (_readerInitialized) {
      await reader.close();
    }
  }

  @override
  Future<void> onRemove() async {
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

  @override
  Future<Map<String, String>> resolveKeys(Iterable<String> words) async {
    await waitForLoading();

    final resolved = <String, String>{};
    for (final word in words) {
      for (final candidate in lookupVariants(word)) {
        // resolveIndex returns an ENTRY index (into the archive's path
        // pointers), while wordAt indexes the ARTICLE list — the two only
        // coincide when no non-article entry sorts before the article, so
        // never feed one to the other. The fetched entry carries its title.
        final index = reader.resolveIndex(candidate);
        if (index != null) {
          final entry = await reader.getEntry(index);
          if (entry.isRedirect) {
            final target = await reader.lookup(candidate);
            resolved[word] = target.isNotEmpty
                ? target.first.title
                : entry.title;
          } else {
            resolved[word] = entry.title;
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
  @override
  Future<Uint8List?> readResourceFile(String filename) async {
    await waitForLoading();
    return reader.readDataByPath(filename);
  }
}

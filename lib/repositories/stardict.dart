import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/base_dictionary.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/services/media_tags.dart";
import "package:ciyue/services/zip_archive_reader.dart";
import "package:ciyue/services/stardict_html.dart";
import "package:ciyue/utils.dart";
import "package:dict_reader/dict_reader.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

/// A StarDict dictionary, implementing [LoadedDictionary] on top of
/// [BaseLoadedDictionary]. [path] is the base path shared by the `.ifo`,
/// `.idx` and `.dict` (or `.dict.dz`) files.
class Stardict extends BaseLoadedDictionary {
  late final StarDictReader reader;
  bool _readerInitialized = false;

  /// Whether the dictionary ships a stylesheet named after itself.
  ///
  /// StarDict has no place in the `.ifo` for app-wide styles, so a converter
  /// or the reader can drop `<name>.css` next to the files (or into `res/`
  /// and `res.zip`). It is linked from every entry when present.
  bool hasCss = false;

  Stardict({required super.path});

  void _ensureReader() {
    if (!_readerInitialized) {
      reader = StarDictReader(path);
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

  Future<void> add() async {
    _ensureReader();
    // The title comes from the `.ifo` alone, so the database row (and the
    // id the cache file is named after) can exist before the full index
    // parse runs — the same ordering `Zim.add` uses.
    await reader.initMetadata();
    setDefaultTitle();
    id = await dictionaryListDao.add(
      path,
      title,
      type: DictionaryType.stardict,
    );
    try {
      await _initReaderWithCache();
    } catch (_) {
      await dictionaryListDao.remove(path);
      rethrow;
    }
    entriesTotal = reader.wordCount;
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
  Future<void> init() => initialization ??= _initialize();

  Future<File?> _cacheFile() async {
    try {
      final dictId = id;
      final cacheDir = await getApplicationCacheDirectory();
      return File(join(cacheDir.path, "dict_reader_${dictId}_stardict.cidx"));
    } catch (e) {
      // A silent null here hides the real reason a cache never appears.
      talker.warning("No StarDict .cidx cache path for $path: $e");
      return null;
    }
  }

  /// Initialises the reader from the cached SDIX index when one exists and
  /// still matches the `.idx`/`.syn` files, and writes the cache after a
  /// full parse otherwise — the same shape as `Zim._initReaderWithCache`.
  /// A stale or invalid cache falls back to a full parse; the import in
  /// dict_reader validates the snapshot before mutating any reader state.
  Future<void> _initReaderWithCache() async {
    final cache = await _cacheFile();
    if (cache != null && await cache.exists()) {
      try {
        final bytes = await cache.readAsBytes();
        await reader.importCidx(bytes);
        return;
      } catch (e) {
        talker.warning("Stale or invalid StarDict .cidx cache for $path: $e");
      }
    }

    await reader.init();
    if (cache != null) {
      // Write the snapshot before returning: exporting after init is what
      // makes the next cold start skip the `.idx` re-parse.
      try {
        final cidxBytes = await reader.exportCidx();
        await cache.writeAsBytes(cidxBytes, flush: true);
      } catch (e, st) {
        talker.error("Failed to write StarDict .cidx cache for $path", e, st);
      }
    }
  }

  Future<void> _initialize() async {
    try {
      _ensureReader();
      await _initReaderWithCache();
      setDefaultTitle();
      entriesTotal = reader.wordCount;
      // The stylesheet can sit next to the dictionary or inside res/ and
      // res.zip; readResourceFile already knows all three places.
      hasCss = await readResourceFile("${basename(path)}.css") != null;
      if (isDesktop()) {
        await startDesktopServer(onReadResource: readResourceFile);
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
    hasCss = false;
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
  Future<void> onRemove() async {
    try {
      final cache = await _cacheFile();
      if (cache != null && await cache.exists()) {
        await cache.delete();
      }
    } catch (_) {}

    if (Platform.isAndroid && !isFullFlavor()) {
      for (final extension in [".ifo", ".idx", ".dict", ".dict.dz", ".syn"]) {
        final file = File("$path$extension");
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  @override
  Future<Map<String, String>> resolveKeys(Iterable<String> words) async {
    await waitForLoading();

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
    Iterable<String> words, {
    Map<String, String>? resolvedKeys,
  }) async {
    // Resolve every candidate to its headword first — reusing the exact keys
    // the caller already computed — then dedup by headword in first-seen
    // order and read each distinct headword once, in parallel. Candidates
    // that fold to one headword (`word`/`Word`/`WORD`) used to be read in
    // full and dropped after; different headwords (`abend`/`Abend`) are
    // still each read.
    final headwords = <String>[];
    final seenHeadwords = <String>{};
    for (final word in words) {
      final headword = resolvedKeys?[word] ?? await resolveExactKey(word);
      if (headword == null) continue;
      if (seenHeadwords.add(headword)) headwords.add(headword);
    }
    // Reads are queued on the reader's file lock, so Future.wait only
    // overlaps the waits — it cannot interleave two reads on the shared
    // handle.
    final entries = await Future.wait(
      headwords.map(
        (headword) => _readEntry(headword, resolvedHeadword: headword),
      ),
    );
    return entries.whereType<DictionaryEntryData>().toList(growable: false);
  }

  final Map<String, List<StarDictField>> _structuredFieldsCache = {};
  static const int _structuredCacheLimit = 64;

  List<StarDictField>? structuredFieldsFor(String headword) =>
      _structuredFieldsCache[headword];

  void _cacheStructuredFields(String headword, List<StarDictField> fields) {
    _structuredFieldsCache[headword] = fields;
    while (_structuredFieldsCache.length > _structuredCacheLimit) {
      _structuredFieldsCache.remove(_structuredFieldsCache.keys.first);
    }
  }

  String get dictionaryDirectory => dirname(path);

  Iterable<String> get _resourceArchivePaths sync* {
    yield join(dictionaryDirectory, "res.zip");
    yield join(dictionaryDirectory, "${basename(path)}.res.zip");
    yield join(dictionaryDirectory, "res", "res.zip");
  }

  final Map<String, ZipArchiveReader?> _zipReaders = {};

  ZipArchiveReader? _zipReaderFor(String archivePath) {
    if (_zipReaders.containsKey(archivePath)) {
      return _zipReaders[archivePath];
    }
    final file = File(archivePath);
    final reader = file.existsSync() ? ZipArchiveReader(file) : null;
    _zipReaders[archivePath] = reader;
    return reader;
  }

  /// Links the dictionary's own stylesheet ahead of the entry HTML.
  ///
  /// Entries are HTML fragments, so a `<link>` before them is valid, the same
  /// convention MDict uses for `<name>.css`.
  @override
  String wrapContentWithResources(String content) {
    final header = hasCss
        ? '<link rel="stylesheet" href="'
              '${Uri.encodeComponent(basename(path))}.css">\n'
        : "";
    return applyDocumentMode(header + rewriteMediaTags(content));
  }

  @override
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

  Future<DictionaryEntryData?> _readEntry(
    String word, {
    String? resolvedHeadword,
  }) async {
    await waitForLoading();
    // Resolve the spelling the dictionary actually holds first. `reader.lookup`
    // only normalises NFC and lower-cases, so a full-width query (`ＮＨＫ`)
    // would miss a half-width headword (`NHK`); [resolveExactKey] runs the
    // width/case variants and is what bridges the two. It returns the stored
    // headword (also for synonyms), which is the key to read.
    final headword = resolvedHeadword ?? await resolveExactKey(word);
    if (headword == null) {
      return null;
    }
    final results = await reader.lookup(headword);
    if (results.isEmpty) {
      return null;
    }
    final displayable = results
        .where((entry) => entry.fields.any((field) => field.text != null))
        .toList();
    if (displayable.isEmpty) {
      return null;
    }
    _cacheStructuredFields(displayable.first.headword, [
      for (final entry in displayable) ...entry.fields,
    ]);
    // The HTML is only read by the WebView; native rendering uses the
    // structured fields cached above. Build it lazily so a native-only
    // entry never pays for the XML-to-HTML conversion.
    return DictionaryEntryData.lazy(
      headword: displayable.first.headword,
      buildContent: () =>
          displayable.map((entry) => stardictEntryToHtml(entry.fields)).join(),
    );
  }

  Future<String> readWord(String word) async {
    final entry = await _readEntry(word);
    if (entry == null) {
      throw Exception("Word not found: $word");
    }
    return entry.content;
  }

  Future<Uint8List?> _readLocalFile(String filename) async {
    if (filename == "favicon.ico") return null;
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

import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/base_dictionary.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/services/zip_archive_reader.dart";
import "package:ciyue/services/stardict_html.dart";
import "package:ciyue/utils.dart";
import "package:dict_reader/dict_reader.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:path/path.dart";

/// A StarDict dictionary, implementing [LoadedDictionary] on top of
/// [BaseLoadedDictionary]. [path] is the base path shared by the `.ifo`,
/// `.idx` and `.dict` (or `.dict.dz`) files.
class Stardict extends BaseLoadedDictionary {
  late final StarDictReader reader;
  bool _readerInitialized = false;

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

  /// Registers a new StarDict dictionary.
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
  Future<void> init() => initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      _ensureReader();
      await reader.init();
      setDefaultTitle();
      entriesTotal = reader.wordCount;
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

  Future<DictionaryEntryData?> _readEntry(String word) async {
    await waitForLoading();
    // Resolve the spelling the dictionary actually holds first. `reader.lookup`
    // only normalises NFC and lower-cases, so a full-width query (`ＮＨＫ`)
    // would miss a half-width headword (`NHK`); [resolveExactKey] runs the
    // width/case variants and is what bridges the two. It returns the stored
    // headword (also for synonyms), which is the key to read.
    final headword = await resolveExactKey(word);
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

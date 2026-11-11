import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/dictionary_links.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/base_dictionary.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/utils.dart";
import "package:dict_reader/dict_reader.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

/// Matches the `href` of an `<a>` element. Only anchors are rewritten: a
/// stylesheet, image or script keeps its own resource URL.
final _anchorHrefPattern = RegExp(
  r'''(<a\b[^>]*?\bhref\s*=\s*)(["'])([^"']*)\2''',
  caseSensitive: false,
);

/// Any `scheme:` prefix names something outside the archive: an external URL,
/// a custom protocol (`geo:`, `zotero:`), or a link the word display handles
/// itself. A dead article path has no scheme, so this is what separates the
/// two when the archive declines a path.
final _schemePattern = RegExp(r"^[a-zA-Z][a-zA-Z0-9+.\-]*:");

/// A path with one of these extensions names a resource, not an article. A
/// missing one keeps its href (the resource request 404s) instead of being
/// turned into a headword lookup.
final _resourceExtensionPattern = RegExp(
  r"\.(?:css|js|mjs|png|jpe?g|gif|svg|webp|ico|bmp|avif|woff2?|ttf|otf|eot|"
  r"mp3|ogg|oga|opus|wav|flac|spx|m4a|mp4|webm|ogv|pdf|zip|json|xml|txt)$",
  caseSensitive: false,
);

/// A ZIM archive (openZIM / Kiwix) dictionary, implementing [LoadedDictionary].
class Zim extends BaseLoadedDictionary {
  late final ZimReader reader;
  bool _readerInitialized = false;

  /// href -> canonical dictionary link, or null when the href is not an
  /// article link. Articles repeat the same targets, so the lookup against
  /// the archive's path index is cached per dictionary.
  final Map<String, String?> _articleLinkHrefs = {};

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
    // wordCount counts parsed articles and is zero until the full index is
    // built. The header's entry count is available right away and is what
    // the properties page calls "total number of entries".
    entriesTotal = reader.entryCount;
  }

  /// Reads the archive's name and entry count without building the index.
  ///
  /// The import dialog uses this to say what the long parse is working on;
  /// [ZimReader.initMetadata] only touches the header and the MIME list.
  Future<({String title, int entries})> inspect() async {
    _ensureReader();
    await reader.initMetadata();
    final name = reader.bookName;
    return (
      title: name.isEmpty ? basename(path) : HtmlUnescape().convert(name),
      entries: reader.entryCount,
    );
  }

  Future<void> add() async {
    _ensureReader();
    // The cache file is named after the dictionary id, so the database row
    // has to exist before the index snapshot is written. Registering last
    // made _cacheFile() read the still-uninitialized late id and silently
    // skip the cache entirely on import.
    await reader.initMetadata();
    setDefaultTitle();
    id = await dictionaryListDao.add(path, title, type: DictionaryType.zim);
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
      // Metadata-only loads back the properties page, where no article
      // index has been parsed yet; wordCount would be zero.
      entriesTotal = reader.entryCount;
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
    } catch (e) {
      // A silent null here hides the real reason a cache never appears.
      talker.warning("No ZIM .cidx cache path for $path: $e");
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
      // Write the snapshot before returning. The import closes this reader as
      // soon as add() finishes, and closing marks the reader uninitialized,
      // so a background export raced close() and silently never produced a
      // cache for large archives — the next open parsed everything again.
      try {
        final cidxBytes = await reader.exportCidx();
        await cache.writeAsBytes(cidxBytes, flush: true);
      } catch (e, st) {
        talker.error("Failed to write ZIM .cidx cache for $path", e, st);
      }
    }
  }

  Future<void> _initialize() async {
    talker.info("ZIM init start: $path");
    try {
      _ensureReader();
      await _initReaderWithCache();
      talker.info("ZIM reader ready: $path words=${reader.wordCount}");
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
        talker.info("ZIM server ready: $path port=$port");
      }
      talker.info("ZIM init done: $path");
    } catch (e) {
      talker.error("ZIM init failed: $path", e);
      initializationError = e;
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  @override
  Future<void> onClose() async {
    _articleLinkHrefs.clear();
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

  /// Turns Kiwix-style article links into dictionary entry links.
  ///
  /// Wikipedia ZIMs link articles with bare, percent-encoded paths such as
  /// `1%E5%B9%B4%E4%BB%A3`. Left alone, the WebView follows them as resource
  /// requests against the local server, which answers with the article as
  /// `application/octet-stream` — a tap that appears to do nothing. HTML and
  /// redirect entries become `gdlookup://` links, audio entries become
  /// `sound://` links, and a path the archive does not answer becomes a
  /// "look this word up" link so a dead link reaches the not-found page.
  /// CSS/JS/images, pure anchors and external URLs keep their original href.
  Future<String> _rewriteArticleLinks(String html) async {
    if (!html.toLowerCase().contains("href")) return html;

    final unresolved = <String>{};
    for (final match in _anchorHrefPattern.allMatches(html)) {
      final href = match[3] ?? "";
      if (!_articleLinkHrefs.containsKey(href)) unresolved.add(href);
    }
    for (final href in unresolved) {
      _articleLinkHrefs[href] = await _articleLinkHref(href);
    }

    return html.replaceAllMapped(_anchorHrefPattern, (match) {
      final href = match[3] ?? "";
      final replacement = _articleLinkHrefs[href];
      if (replacement == null) return match[0]!;
      final quote = match[2]!;
      return "${match[1]}$quote$replacement$quote";
    });
  }

  Future<String?> _articleLinkHref(String rawHref) async {
    if (rawHref.isEmpty ||
        rawHref.startsWith("#") ||
        rawHref.startsWith("//")) {
      return null;
    }

    final hash = rawHref.indexOf("#");
    final path = hash < 0 ? rawHref : rawHref.substring(0, hash);
    if (path.isEmpty) return null;

    // Entries may legitimately be named `A:B@C` — `:` and `@` are ordinary
    // path characters, and ZIM paths are not file names — so a scheme-looking
    // prefix is only treated as external after the archive declines the path.
    ZimEntry? entry;
    try {
      entry = await reader.getEntryByPath(path);
    } catch (_) {
      return _deadLinkHref(path);
    }
    if (entry == null) return _deadLinkHref(path);

    final mime = entry.mimeType.toLowerCase();
    if (mime.startsWith("audio/")) {
      // entry.fullPath is the key readResourceFile() resolves; the percent
      // encoding keeps `:`, `@`, `#` and upper-case ASCII intact.
      return soundLinkHref(entry.fullPath);
    }
    if (!entry.isRedirect &&
        !mime.startsWith("text/html") &&
        !mime.startsWith("application/xhtml")) {
      return null;
    }

    var anchor = hash < 0 ? null : rawHref.substring(hash + 1);
    if (anchor != null && anchor.isNotEmpty) {
      try {
        anchor = Uri.decodeComponent(anchor);
      } catch (_) {}
    }
    // The dirent title is the headword: it may be the unescaped spelling of
    // the encoded path, and lookup() follows redirect titles for us.
    final href = entryLinkHref(
      EntryLinkTarget(word: entry.title, anchor: anchor),
    );
    return href.isEmpty ? null : href;
  }

  /// A "look up this word" target for a path the archive does not answer.
  ///
  /// A missing article is still a reader intent: the word display shows its
  /// "not found" page (with a search box and this word) instead of the blank
  /// 404 the local content server would return. Kiwix slugs spell spaces as
  /// `_`, so that is undone both for display and for a chance to match the
  /// same headword in another dictionary.
  String? _deadLinkHref(String rawPath) {
    if (_schemePattern.hasMatch(rawPath) ||
        _resourceExtensionPattern.hasMatch(rawPath.split("?").first)) {
      return null;
    }

    var word = rawPath;
    try {
      word = Uri.decodeComponent(word);
    } catch (_) {}
    // `../A/Foo` and `C/Foo` name the entry by their last segment.
    final slash = word.lastIndexOf("/");
    if (slash >= 0) word = word.substring(slash + 1);
    word = word.replaceAll(RegExp(r"_+"), " ").trim();
    if (word.isEmpty) return null;

    final href = entryLinkHref(EntryLinkTarget(word: word));
    return href.isEmpty ? null : href;
  }

  @override
  Future<List<DictionaryEntryData>> readExactEntries(
    Iterable<String> words,
  ) async {
    // A dictionary stuck in initialization must not pin the lookup (and the
    // page's spinner) forever; the caller treats the timeout as "no entries".
    await waitForLoading().timeout(const Duration(seconds: 30));
    final entries = <DictionaryEntryData>[];
    final seenHeadwords = <String>{};

    for (final word in words) {
      final results = await reader.lookup(word);
      if (results.isEmpty) continue;
      final entry = results.first;
      if (seenHeadwords.add(entry.title)) {
        final content = await _rewriteArticleLinks(await entry.readText());
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

  /// ZIM dirents declare their MIME type. A file-name guess cannot recover it
  /// for articles whose path has no extension (`C/1世纪`), which is why the
  /// local server used to answer those with `application/octet-stream`.
  @override
  Future<String?> resourceMimeType(String filename) async {
    await waitForLoading();
    try {
      final entry = await reader.getEntryByPath(filename);
      return entry?.mimeType;
    } catch (_) {
      return null;
    }
  }

  /// Resolves a local-server URL path (a `meta refresh` target, for example)
  /// back to the article's headword so the navigation can go through lookup.
  @override
  Future<String?> entryTitleAtPath(String path) async {
    if (path.isEmpty || path == "favicon.ico") return null;
    try {
      await waitForLoading().timeout(const Duration(seconds: 30));
    } catch (_) {
      return null;
    }
    try {
      final entry = await reader.getEntryByPath(path);
      if (entry == null) return null;
      final mime = entry.mimeType.toLowerCase();
      if (!entry.isRedirect &&
          !mime.startsWith("text/html") &&
          !mime.startsWith("application/xhtml")) {
        return null;
      }
      return entry.title;
    } catch (_) {
      return null;
    }
  }
}

import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/base_dictionary.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/utils.dart";
import "package:markdown/markdown.dart" as markdown;

/// Renders user-authored Markdown to HTML that is safe to load into the
/// entry WebView.
///
/// `markdownToHtml` passes raw HTML through untouched, so without this an
/// imported entry could run scripts in the WebView. The sanitizer drops
/// tags whose content must never execute (`script`/`style`/`iframe`/
/// `object`/…), strips event-handler attributes (`onerror`, …) and any
/// attribute whose URL uses a dangerous scheme (`javascript:`/`data:`/
/// `vbscript:`/`file:`, including entity-encoded spellings such as
/// `javascript&#58;`). Ordinary markup (`<p>`, `<strong>`, safe links and
/// images) passes through unchanged.
String sanitizePersonalDictionaryHtml(String html) {
  var result = html;
  // Repeat the tag passes: a nested trick such as `<scr<script>ipt>`
  // only becomes a plain `<script>` tag once the inner one is removed.
  for (var pass = 0; pass < 3; pass++) {
    final before = result;
    // Tags whose *content* must never reach the WebView.
    for (final tag in const [
      "script",
      "style",
      "iframe",
      "object",
      "applet",
      "frame",
      "frameset",
    ]) {
      result = result.replaceAll(
        RegExp(
          "<$tag\\b[^>]*>.*?</$tag\\s*>",
          caseSensitive: false,
          dotAll: true,
        ),
        "",
      );
      result = result.replaceAll(
        RegExp("<$tag\\b[^>]*>", caseSensitive: false),
        "",
      );
    }
    // Void or metadata tags: drop the tag itself.
    for (final tag in const [
      "embed",
      "link",
      "meta",
      "base",
      "input",
      "keygen",
    ]) {
      result = result.replaceAll(
        RegExp("<$tag\\b[^>]*/?>", caseSensitive: false),
        "",
      );
    }
    // Form controls: drop the tags, keep any inner text.
    for (final tag in const ["form", "button", "select", "textarea", "title"]) {
      result = result.replaceAll(
        RegExp("</?$tag\\b[^>]*>", caseSensitive: false),
        "",
      );
    }
    if (result == before) break;
  }
  // Event-handler attributes, quoted or not: onerror, onclick, onbegin…
  result = result.replaceAll(
    RegExp(
      "\\s+on\\w+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)",
      caseSensitive: false,
    ),
    "",
  );
  // Inline styles are only dangerous when they can run code or load a
  // dangerous URL; plain styles (e.g. `<span style="color:red">`) stay.
  result = result.replaceAllMapped(
    RegExp(
      "\\s+style\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)",
      caseSensitive: false,
    ),
    (match) {
      final value = match.group(1)!;
      if (RegExp(
        "expression\\s*\\(|javascript\\s*:|vbscript\\s*:|behaviour\\s*:|"
        "url\\s*\\(\\s*['\"]?\\s*(data|javascript)\\s*:",
        caseSensitive: false,
      ).hasMatch(value)) {
        return "";
      }
      return match.group(0)!;
    },
  );
  // URL attributes with a dangerous scheme. The check runs on the value
  // with whitespace/control characters stripped and numeric character
  // references decoded, so `java\tscript:` and `javascript&#58;` are
  // caught too.
  result = result.replaceAllMapped(
    RegExp(
      "\\s+(href|src|action|formaction|poster|cite|background|xlink:href)"
      "\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)",
      caseSensitive: false,
    ),
    (match) {
      final raw = match.group(2)!;
      final value =
          raw.length >= 2 &&
              ((raw.startsWith("\"") && raw.endsWith("\"")) ||
                  (raw.startsWith("'") && raw.endsWith("'")))
          ? raw.substring(1, raw.length - 1)
          : raw;
      return _isDangerousUrl(value) ? "" : match.group(0)!;
    },
  );
  return result;
}

bool _isDangerousUrl(String value) {
  var decoded = value.replaceAll(RegExp(r"[\x00-\x20]"), "");
  decoded = decoded.replaceAllMapped(
    RegExp(r"&#x([0-9a-fA-F]+);?"),
    (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
  );
  decoded = decoded.replaceAllMapped(
    RegExp(r"&#([0-9]+);?"),
    (match) => String.fromCharCode(int.parse(match.group(1)!)),
  );
  decoded = decoded
      .replaceAll(RegExp(r"&colon;", caseSensitive: false), ":")
      .replaceAll(RegExp(r"&tab;", caseSensitive: false), "")
      .replaceAll(RegExp(r"&newline;", caseSensitive: false), "");
  decoded = decoded.toLowerCase();
  return decoded.startsWith("javascript:") ||
      decoded.startsWith("vbscript:") ||
      decoded.startsWith("data:") ||
      decoded.startsWith("file:");
}

/// Whether [path] is the sentinel path of a personal dictionary
/// (`personal:<id>`), rather than a file path.
bool isPersonalDictionaryPath(String path) => path.startsWith("personal:");

/// The dictionary id carried by a personal-dictionary sentinel path, or
/// null when [path] is not one.
int? personalDictionaryIdFromPath(String path) {
  if (!isPersonalDictionaryPath(path)) return null;
  return int.tryParse(path.substring("personal:".length));
}

/// A user-authored dictionary whose entries live in the app database
/// ([PersonalArticles] / [PersonalHeadwords]), not in a file.
///
/// [path] is the sentinel `personal:<id>` (see [isPersonalDictionaryPath]);
/// loading reads the [DictionaryList] row for that id and nothing else, so
/// a personal dictionary never touches the file system. Article bodies are
/// Markdown source, converted to HTML at read time so entries flow through
/// the existing word-display pipeline unchanged. Entry HTML goes through
/// the base [wrapContentWithResources] (standards-mode doctype plus the
/// media-tag rewrite, as for Mdict) rather than passing through untouched
/// (P2-22): personal entries are fragments too, and the WebView must not
/// render them in quirks mode.
class PersonalDictionary extends BaseLoadedDictionary {
  /// A test database. Null in production, where the shared [mainDatabase]
  /// is used. Kept unresolved until first use so merely constructing a
  /// dictionary (e.g. in `createLoadedDictionary`) never opens the global
  /// database.
  final AppDatabase? _databaseOverride;

  PersonalDictionary({required super.path, AppDatabase? database})
    : _databaseOverride = database;

  AppDatabase get _db => _databaseOverride ?? mainDatabase;

  DictionaryListDao get _dictionaryListDao => DictionaryListDao(_db);

  DictGroupDao get _dictGroupDao => DictGroupDao(_db);

  PersonalDictionaryDao get _dao => PersonalDictionaryDao(_db);

  bool _metadataLoaded = false;

  /// True once the [DictionaryList] row has been read; a personal
  /// dictionary has no index or server to wait for, so metadata is all
  /// loading there is.
  @override
  bool get isReady => _metadataLoaded && initializationError == null;

  @override
  Future<void> initMetadata() =>
      metadataInitialization ??= _initializeMetadata();

  Future<void> _initializeMetadata() async {
    final parsedId = personalDictionaryIdFromPath(path);
    if (parsedId == null) {
      throw StateError("Personal dictionary path is not personal:<id>: $path");
    }
    id = parsedId;
    type = DictionaryType.personal;
    final row = await _dictionaryListDao.getById(id);
    if (row == null) {
      throw StateError("No personal dictionary with id $id");
    }
    if (row.type != DictionaryType.personal) {
      throw StateError(
        "Dictionary $id is not a personal dictionary (type ${row.type})",
      );
    }
    title = row.title ?? "personal:$id";
    entriesTotal = await _dao.countArticles(id);
    _metadataLoaded = true;
    isLoading = false;
  }

  @override
  Future<void> init() => initialization ??= _initialize();

  Future<void> _initialize() async {
    // Starts a new init cycle: clears the closed flag left by an earlier
    // close() so this cycle may bind a server again, and hands the
    // generation to startDesktopServer so a close in the meantime
    // invalidates this cycle instead of leaking a server (P1-4/P1-6).
    final generation = beginInitialization();
    try {
      await initMetadata();
      entriesTotal = await _dao.countArticles(id);
      if (isDesktop()) {
        // The desktop entry WebView waits for this dictionary's loopback
        // server port before loading content (WebviewWindows gives up
        // when the port stays 0 after loading), so a personal dictionary
        // needs a server exactly like a file dictionary, even though it
        // serves no resources. Without it the word page shows the section
        // header but the entry body never loads.
        await startDesktopServer(generation: generation);
      }
    } catch (e) {
      _metadataLoaded = false;
      initializationError = e;
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  @override
  Future<void> initOnlyMetadata(int id) async {
    this.id = id;
    type = DictionaryType.personal;
    final row = await _dictionaryListDao.getById(id);
    if (row == null) {
      throw StateError("No personal dictionary with id $id");
    }
    title = row.title ?? "personal:$id";
    entriesTotal = await _dao.countArticles(id);
    _metadataLoaded = true;
    isLoading = false;
  }

  @override
  Future<void> onClose() async {
    // A closed dictionary is not ready: without this, isReady stays true
    // after close() and a later init() would have to notice the stale
    // metadata state itself (P1-6).
    _metadataLoaded = false;
  }

  /// Personal dictionaries have no description of their own.
  @override
  String get description => "";

  /// The stored title is the dictionary's own title, so there is nothing
  /// to reset to.
  @override
  void setDefaultTitle() {}

  @override
  Future<List<String>> search(
    String query, {
    int limit = defaultHeadwordSearchLimit,
  }) async {
    await waitForLoading();
    final normalized = normalizePersonalHeadword(query.trim());
    if (normalized.isEmpty) return [];
    // No blanket catch here (P2-5): a database error must propagate to
    // the caller instead of masquerading as "no results", matching
    // resolveKeys.
    final rows = await _dao.searchHeadwords(id, normalized, limit: limit);
    return rows.map((row) => row.headword).toList();
  }

  @override
  Future<Map<String, String>> resolveKeys(Iterable<String> words) async {
    await waitForLoading();
    final candidatesByNormalized = <String, List<String>>{};
    for (final word in words) {
      // Trim like search does (P2-6): " apple " must resolve the same
      // way "apple" does. The map stays keyed by the caller's original
      // word, so resolveExactKey finds its answer under the word it was
      // given.
      final trimmed = word.trim();
      if (trimmed.isEmpty) continue;
      (candidatesByNormalized[normalizePersonalHeadword(trimmed)] ??= []).add(
        word,
      );
    }
    if (candidatesByNormalized.isEmpty) return {};
    final rows = await _dao.resolveHeadwords(id, candidatesByNormalized.keys);
    final resolved = <String, String>{};
    for (final entry in candidatesByNormalized.entries) {
      final row = rows[entry.key];
      if (row == null) continue;
      for (final candidate in entry.value) {
        resolved[candidate] = row.headword;
      }
    }
    return resolved;
  }

  @override
  Future<List<DictionaryEntryData>> readExactEntries(
    Iterable<String> words, {
    Map<String, String>? resolvedKeys,
  }) async {
    // Complete the caller's partial keys word by word — the same contract
    // as Mdict's readExactEntries — instead of replacing the whole map:
    // the lookup passes only the exact key it already resolved, and the
    // remaining candidates (a kana or width variant of the same word) must
    // still be resolved, not silently dropped.
    final headwords = <String>[];
    final seenHeadwords = <String>{};
    for (final word in words) {
      final headword = resolvedKeys?[word] ?? await resolveExactKey(word);
      if (headword == null) continue;
      if (seenHeadwords.add(headword)) headwords.add(headword);
    }
    if (headwords.isEmpty) return [];
    final rows = await _dao.resolveHeadwords(
      id,
      headwords.map(normalizePersonalHeadword),
    );
    // One batch fetch for all articles (P2-7): the old code resolved the
    // same headwords a second time and then awaited getArticle once per
    // headword. The per-headword results are identical — one entry per
    // resolved headword, in the same order, with the stored headword
    // spelling — only the query pattern changed.
    final articleIdByHeadword = <String, int>{};
    final articleIds = <int>[];
    final seenArticleIds = <int>{};
    for (final headword in headwords) {
      final row = rows[normalizePersonalHeadword(headword)];
      if (row == null) continue;
      articleIdByHeadword[headword] = row.articleId;
      if (seenArticleIds.add(row.articleId)) articleIds.add(row.articleId);
    }
    if (articleIds.isEmpty) return [];
    final articles = await _dao.articlesByIds(articleIds);
    final articleById = {for (final article in articles) article.id: article};
    final entries = <DictionaryEntryData>[];
    for (final headword in headwords) {
      final articleId = articleIdByHeadword[headword];
      if (articleId == null) continue;
      final article = articleById[articleId];
      if (article == null) continue;
      entries.add(
        DictionaryEntryData(
          headword: rows[normalizePersonalHeadword(headword)]!.headword,
          content: sanitizePersonalDictionaryHtml(
            markdown.markdownToHtml(article.body),
          ),
        ),
      );
    }
    return entries;
  }

  /// Personal dictionaries have no resource files.
  @override
  Future<Uint8List?> readResourceFile(String filename) async => null;

  /// Deletes the dictionary's articles and headwords plus its
  /// [DictionaryList] row, and removes the id from every dictionary
  /// group. No file path is involved: the sentinel path is not a file,
  /// and personal dictionaries own no files. The data delete, the row
  /// delete and the group cleanup run in one transaction (P2-3, P2-4),
  /// so a failure mid-delete cannot leave a half-removed dictionary.
  @override
  Future<void> removeDictionary({int? dictionaryId}) async {
    final removeId = dictionaryId ?? id;
    await _db.transaction(() async {
      await _dao.deleteDictionaryData(removeId);
      await _dictionaryListDao.removeById(removeId);
      await _dictGroupDao.removeDictIdFromAllGroups(removeId);
    });
  }
}

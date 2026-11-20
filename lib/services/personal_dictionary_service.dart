import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/database/app/tables.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:drift/drift.dart";

/// Maximum length of a personal dictionary name, in characters.
///
/// `addGroup` (the dictionary-group counterpart) has no length limit, so
/// there is no shared constant to reuse; 100 keeps names readable on the
/// dictionary cards while leaving room for long titles.
const personalDictionaryNameMaxLength = 100;

/// One non-blocking warning from a DSL import, localised at the point of
/// display: the service has no [BuildContext], so it reports the kind and
/// the entry it belongs to and the UI renders [message].
class PersonalDslWarning {
  final PersonalDslWarningKind kind;

  /// Headwords of the skipped entry, for [PersonalDslWarningKind.noBody],
  /// [PersonalDslWarningKind.duplicate] and
  /// [PersonalDslWarningKind.invalidEntry]; empty otherwise.
  final String headwords;

  /// Number of skipped lines, for
  /// [PersonalDslWarningKind.orphanBodyLines]; 0 otherwise.
  final int count;

  const PersonalDslWarning(this.kind, [this.headwords = "", this.count = 0]);

  @override
  bool operator ==(Object other) =>
      other is PersonalDslWarning &&
      other.kind == kind &&
      other.headwords == headwords &&
      other.count == count;

  @override
  int get hashCode => Object.hash(kind, headwords, count);

  String message(AppLocalizations l10n) {
    return switch (kind) {
      PersonalDslWarningKind.tags => l10n.personalDictionaryImportWarningTags,
      PersonalDslWarningKind.tilde => l10n.personalDictionaryImportWarningTilde,
      PersonalDslWarningKind.parentheses =>
        l10n.personalDictionaryImportWarningParentheses,
      PersonalDslWarningKind.doubleBraces =>
        l10n.personalDictionaryImportWarningDoubleBraces,
      PersonalDslWarningKind.noBody =>
        l10n.personalDictionaryImportWarningNoBody(headwords),
      PersonalDslWarningKind.duplicate =>
        l10n.personalDictionaryImportWarningDuplicate(headwords),
      PersonalDslWarningKind.orphanBodyLines =>
        l10n.personalDictionaryImportWarningOrphanBodyLines(count),
      PersonalDslWarningKind.invalidEntry =>
        l10n.personalDictionaryImportWarningInvalidEntry(headwords),
    };
  }
}

enum PersonalDslWarningKind {
  tags,
  tilde,
  parentheses,
  doubleBraces,
  noBody,
  duplicate,
  orphanBodyLines,
  invalidEntry,
}

/// One article of a personal dictionary, with all of its headwords.
class PersonalEntry {
  final int articleId;
  final int dictionaryId;
  final List<String> headwords;
  final String body;
  final DateTime updatedAt;

  const PersonalEntry({
    required this.articleId,
    required this.dictionaryId,
    required this.headwords,
    required this.body,
    required this.updatedAt,
  });
}

/// The outcome of a DSL import: how many articles were stored, and the
/// non-blocking warnings for entries that were skipped or stored verbatim
/// (DSL constructs this dictionary keeps as plain text).
class PersonalDslImportResult {
  final int imported;
  final List<PersonalDslWarning> warnings;

  const PersonalDslImportResult({
    required this.imported,
    this.warnings = const [],
  });
}

/// Creates and edits personal dictionaries and their entries.
///
/// A personal dictionary is a [DictionaryList] row of type
/// [DictionaryType.personal] whose path is the sentinel `personal:<id>`;
/// its articles live in [PersonalArticles] and its headwords in
/// [PersonalHeadwords]. Nothing here touches the file system.
class PersonalDictionaryService {
  final AppDatabase db;

  PersonalDictionaryService(this.db);

  DictionaryListDao get _dictionaryListDao => DictionaryListDao(db);

  PersonalDictionaryDao get _dao => PersonalDictionaryDao(db);

  /// Throws unless [id] is the id of a personal dictionary.
  Future<void> _requirePersonalDictionary(int id) async {
    final type = await _dictionaryListDao.getType(id);
    if (type != DictionaryType.personal) {
      throw StateError(
        "Dictionary $id is not a personal dictionary (type $type)",
      );
    }
  }

  /// Whether [id] is the id of an existing personal dictionary. A
  /// missing row or a row of another type is not one.
  Future<bool> dictionaryExists(int id) async {
    try {
      return await _dictionaryListDao.getType(id) == DictionaryType.personal;
    } catch (_) {
      return false;
    }
  }

  /// Whether a personal dictionary named [name] already exists
  /// (case-insensitive), ignoring the dictionary [exceptId] when given,
  /// so renaming a dictionary to its own name is allowed.
  Future<bool> dictionaryNameExists(String name, {int? exceptId}) async {
    final wanted = name.trim().toLowerCase();
    if (wanted.isEmpty) return false;
    final dictionaries = await _dictionaryListDao.all();
    return dictionaries.any(
      (dictionary) =>
          dictionary.type == DictionaryType.personal &&
          dictionary.id != exceptId &&
          (dictionary.title ?? "").toLowerCase() == wanted,
    );
  }

  /// The headword of another article of [dictionaryId] that already owns
  /// one of [headwords], or null when they are all free. [exceptArticleId]
  /// is the article being edited: its own headwords do not conflict.
  Future<String?> findConflictingHeadword(
    int dictionaryId,
    List<String> headwords, {
    int? exceptArticleId,
  }) async {
    final existing = await _dao.resolveHeadwords(
      dictionaryId,
      headwords.map(normalizePersonalHeadword),
    );
    for (final row in existing.values) {
      if (row.articleId != exceptArticleId) return row.headword;
    }
    return null;
  }

  /// Creates a personal dictionary named [name] and returns its id.
  ///
  /// The list row is created first so the id is assigned by the database,
  /// then the sentinel path `personal:<id>` is written back onto it.
  Future<int> createDictionary(String name) async {
    final title = name.trim();
    if (title.isEmpty) {
      throw ArgumentError("Dictionary name must not be empty");
    }
    if (title.length > personalDictionaryNameMaxLength) {
      throw ArgumentError(
        "Dictionary name must be at most "
        "$personalDictionaryNameMaxLength characters",
      );
    }
    if (await dictionaryNameExists(title)) {
      throw StateError("A personal dictionary named “$title” already exists");
    }
    final id = await _dictionaryListDao.add(
      "",
      title,
      type: DictionaryType.personal,
    );
    await _dictionaryListDao.updatePath(id, "personal:$id");
    return id;
  }

  Future<void> renameDictionary(int id, String name) async {
    final title = name.trim();
    if (title.isEmpty) {
      throw ArgumentError("Dictionary name must not be empty");
    }
    if (title.length > personalDictionaryNameMaxLength) {
      throw ArgumentError(
        "Dictionary name must be at most "
        "$personalDictionaryNameMaxLength characters",
      );
    }
    await _requirePersonalDictionary(id);
    if (await dictionaryNameExists(title, exceptId: id)) {
      throw StateError("A personal dictionary named “$title” already exists");
    }
    await _dictionaryListDao.updateTitle(id, title);
  }

  Future<void> deleteDictionary(int id) async {
    await _requirePersonalDictionary(id);
    await _dao.deleteDictionaryData(id);
    await _dictionaryListDao.removeById(id);
  }

  Future<List<PersonalEntry>> listEntries(
    int dictionaryId, {
    String? query,
  }) async {
    final normalizedPrefix = query == null || query.trim().isEmpty
        ? null
        : normalizePersonalHeadword(query.trim());
    final headwords = await _dao.headwordsForDictionary(
      dictionaryId,
      normalizedPrefix: normalizedPrefix,
    );
    if (headwords.isEmpty) return [];
    // A set keeps insertion order, so articles come out in the order their
    // first headword appears in the headword-ordered query.
    final articleIds = <int>{};
    final headwordsByArticle = <int, List<String>>{};
    for (final headword in headwords) {
      (headwordsByArticle[headword.articleId] ??= []).add(headword.headword);
      articleIds.add(headword.articleId);
    }
    final articles = await _dao.articlesForDictionary(dictionaryId);
    final articleById = {for (final article in articles) article.id: article};
    return [
      for (final articleId in articleIds)
        if (articleById[articleId] != null)
          PersonalEntry(
            articleId: articleId,
            dictionaryId: dictionaryId,
            headwords: headwordsByArticle[articleId]!,
            body: articleById[articleId]!.body,
            updatedAt: articleById[articleId]!.updatedAt,
          ),
    ];
  }

  Future<int> entryCount(int dictionaryId) {
    return _dao.countArticles(dictionaryId);
  }

  /// Creates one article filed under [headwords] (aliases sharing the
  /// article) and returns the article id.
  ///
  /// Headwords are trimmed, empties dropped and duplicates (after
  /// normalisation) collapsed; an empty headword list or an empty body is
  /// an error, as is a headword that already belongs to another article of
  /// this dictionary.
  Future<int> createEntry(
    int dictionaryId, {
    required List<String> headwords,
    required String body,
  }) async {
    await _requirePersonalDictionary(dictionaryId);
    final cleaned = _cleanHeadwords(headwords);
    if (cleaned.isEmpty) {
      throw ArgumentError("At least one headword is required");
    }
    if (body.trim().isEmpty) {
      throw ArgumentError("Entry body must not be empty");
    }
    await _requireHeadwordsFree(dictionaryId, cleaned);
    final now = DateTime.now();
    return db.transaction(() async {
      final articleId = await _dao.insertArticle(
        PersonalArticlesCompanion(
          dictionaryId: Value(dictionaryId),
          body: Value(body),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _dao.insertHeadwords(
        _headwordCompanions(dictionaryId, articleId, cleaned),
      );
      return articleId;
    });
  }

  Future<void> updateEntry(
    int articleId, {
    required List<String> headwords,
    required String body,
  }) async {
    final article = await _dao.getArticle(articleId);
    if (article == null) {
      throw StateError("No personal entry with id $articleId");
    }
    await _requirePersonalDictionary(article.dictionaryId);
    final cleaned = _cleanHeadwords(headwords);
    if (cleaned.isEmpty) {
      throw ArgumentError("At least one headword is required");
    }
    if (body.trim().isEmpty) {
      throw ArgumentError("Entry body must not be empty");
    }
    await _requireHeadwordsFree(
      article.dictionaryId,
      cleaned,
      exceptArticleId: articleId,
    );
    await db.transaction(() async {
      await _dao.updateArticle(
        articleId,
        PersonalArticlesCompanion(
          body: Value(body),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _dao.replaceHeadwords(
        articleId,
        _headwordCompanions(article.dictionaryId, articleId, cleaned),
      );
    });
  }

  Future<void> deleteEntry(int articleId) async {
    final article = await _dao.getArticle(articleId);
    if (article == null) {
      throw StateError("No personal entry with id $articleId");
    }
    await _dao.deleteArticle(articleId);
  }

  /// Exports the dictionary in the tag-free DSL subset [importDsl] reads:
  /// one headword per line, then the body lines indented with a tab.
  ///
  /// Common Markdown is converted to DSL tags where a direct equivalent
  /// exists (`**bold**` to `[b]...[/b]`, `*italic*` to `[i]...[/i]`, list
  /// items to `[m1]` lines, inline code to plain text); anything else is
  /// stripped to plain text.
  Future<String> exportDsl(int dictionaryId) async {
    final entries = await listEntries(dictionaryId);
    final buffer = StringBuffer();
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) buffer.writeln();
      final entry = entries[i];
      for (final headword in entry.headwords) {
        buffer.writeln(headword);
      }
      for (final line in _markdownToDslLines(entry.body)) {
        buffer.writeln("\t$line");
      }
    }
    return buffer.toString();
  }

  Future<PersonalDslImportResult> importDsl(
    int dictionaryId,
    String content,
  ) async {
    await _requirePersonalDictionary(dictionaryId);
    final skippedOrphanBodyLines = <String>[];
    final articles = _parseDsl(
      content,
      skippedOrphanBodyLines: skippedOrphanBodyLines,
    );
    var imported = 0;
    final warnings = <PersonalDslWarning>[];
    if (skippedOrphanBodyLines.isNotEmpty) {
      warnings.add(
        PersonalDslWarning(
          PersonalDslWarningKind.orphanBodyLines,
          "",
          skippedOrphanBodyLines.length,
        ),
      );
    }
    final warnedKinds = <PersonalDslWarningKind>{};
    for (final article in articles) {
      for (final kind in _dslWarningKinds(article.rawLines)) {
        if (warnedKinds.add(kind)) warnings.add(PersonalDslWarning(kind));
      }
      if (article.body.trim().isEmpty) {
        warnings.add(
          PersonalDslWarning(
            PersonalDslWarningKind.noBody,
            article.headwords.join(", "),
          ),
        );
        continue;
      }
      try {
        await createEntry(
          dictionaryId,
          headwords: article.headwords,
          body: article.body,
        );
        imported++;
      } on StateError catch (e) {
        // A headword that already belongs to another article: skip this
        // article instead of aborting the whole import. Any other state
        // error (the dictionary vanished mid-import, for instance) is not
        // a duplicate and still aborts.
        if (!e.message.contains("already exists")) rethrow;
        warnings.add(
          PersonalDslWarning(
            PersonalDslWarningKind.duplicate,
            article.headwords.join(", "),
          ),
        );
      } on ArgumentError catch (_) {
        // A headword that trims to nothing (or an empty body): skip this
        // article instead of aborting the whole import, same as for
        // duplicates, and name the skipped entry in the warning.
        final display = article.headwords.join(", ").trim().isEmpty
            ? "<empty headword>"
            : article.headwords.join(", ");
        warnings.add(
          PersonalDslWarning(PersonalDslWarningKind.invalidEntry, display),
        );
      }
    }
    return PersonalDslImportResult(imported: imported, warnings: warnings);
  }

  /// Imports DSL from raw bytes: gunzips when [filename] ends with `.dz`
  /// or the bytes carry the gzip magic, then decodes by BOM (UTF-8/16/32
  /// LE/BE, otherwise UTF-8) and imports as [importDsl].
  Future<PersonalDslImportResult> importDslBytes(
    int dictionaryId,
    Uint8List bytes,
    String filename,
  ) async {
    var data = bytes;
    if (filename.toLowerCase().endsWith(".dz") || _isGzip(data)) {
      data = Uint8List.fromList(gzip.decode(data));
    }
    return importDsl(dictionaryId, _decodeText(data));
  }

  /// Trims headwords, drops empties, and collapses spellings that fold to
  /// the same normalized form, keeping the first spelling.
  List<String> _cleanHeadwords(List<String> headwords) {
    final seen = <String>{};
    final cleaned = <String>[];
    for (final headword in headwords) {
      final trimmed = headword.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(normalizePersonalHeadword(trimmed))) {
        cleaned.add(trimmed);
      }
    }
    return cleaned;
  }

  List<PersonalHeadwordsCompanion> _headwordCompanions(
    int dictionaryId,
    int articleId,
    List<String> headwords,
  ) {
    return [
      for (final headword in headwords)
        PersonalHeadwordsCompanion(
          dictionaryId: Value(dictionaryId),
          articleId: Value(articleId),
          headword: Value(headword),
          normalizedHeadword: Value(normalizePersonalHeadword(headword)),
        ),
    ];
  }

  /// Throws when any of [headwords] already belongs to another article of
  /// [dictionaryId] (or to any article, when [exceptArticleId] is null).
  Future<void> _requireHeadwordsFree(
    int dictionaryId,
    List<String> headwords, {
    int? exceptArticleId,
  }) async {
    final conflict = await findConflictingHeadword(
      dictionaryId,
      headwords,
      exceptArticleId: exceptArticleId,
    );
    if (conflict != null) {
      throw StateError(
        "Headword “$conflict” already exists in this dictionary",
      );
    }
  }
}

/// One article parsed from DSL text: its headwords, its body (indented
/// lines joined with `\n`), and the raw lines it came from, used for the
/// tag warnings.
class _DslArticle {
  final List<String> headwords;
  final String body;
  final List<String> rawLines;

  const _DslArticle({
    required this.headwords,
    required this.body,
    required this.rawLines,
  });
}

/// Splits DSL text into articles: a non-indented line is a headword, the
/// indented lines after it are the article body. A blank line ends the
/// current article, and so does a headword line after body lines.
///
/// A blank line inside a body is kept as an empty body line (a paragraph
/// break), not an article separator. Lines starting with `#` before any
/// headword has been collected are DSL metadata (`#NAME`,
/// `#INDEX_LANGUAGE`, ...) or comments, not headwords; indented body lines
/// (such as a Markdown heading) are never treated as metadata. A body line
/// with no headword above it is skipped and recorded in
/// [skippedOrphanBodyLines] instead of failing the whole import.
List<_DslArticle> _parseDsl(
  String content, {
  List<String>? skippedOrphanBodyLines,
}) {
  final articles = <_DslArticle>[];
  var headwords = <String>[];
  var bodyLines = <String>[];
  var rawLines = <String>[];
  var hasBody = false;

  void flush() {
    if (headwords.isEmpty) return;
    while (bodyLines.isNotEmpty && bodyLines.first.isEmpty) {
      bodyLines.removeAt(0);
    }
    while (bodyLines.isNotEmpty && bodyLines.last.isEmpty) {
      bodyLines.removeLast();
    }
    articles.add(
      _DslArticle(
        headwords: List.of(headwords),
        body: bodyLines.join("\n"),
        rawLines: List.of(rawLines),
      ),
    );
    headwords = [];
    bodyLines = [];
    rawLines = [];
    hasBody = false;
  }

  for (final rawLine in content.split("\n")) {
    // Tolerate CRLF input: the carriage return is line-ending noise.
    final line = rawLine.endsWith("\r")
        ? rawLine.substring(0, rawLine.length - 1)
        : rawLine;
    if (line.isEmpty) {
      if (hasBody) {
        // A blank line inside a body is a paragraph break.
        bodyLines.add("");
        rawLines.add(line);
      } else {
        flush();
      }
      continue;
    }
    if (line.startsWith("#") && headwords.isEmpty && !hasBody) {
      // DSL metadata or a comment line before any entry: not a headword.
      continue;
    }
    if (line.startsWith(" ") || line.startsWith("\t")) {
      if (headwords.isEmpty) {
        // An orphan body line: skip it instead of failing the import.
        skippedOrphanBodyLines?.add(line);
        continue;
      }
      hasBody = true;
      bodyLines.add(_deindent(line));
      rawLines.add(line);
    } else {
      if (hasBody) flush();
      headwords.add(line.trim());
      rawLines.add(line);
    }
  }
  flush();
  return articles;
}

/// Removes one level of DSL body indentation: a single leading tab, or the
/// leading spaces when the line is space-indented.
String _deindent(String line) {
  if (line.startsWith("\t")) return line.substring(1);
  return line.replaceFirst(RegExp("^ +"), "");
}

/// DSL constructs this dictionary keeps as plain text, each reported once
/// per import.
Set<PersonalDslWarningKind> _dslWarningKinds(List<String> rawLines) {
  final kinds = <PersonalDslWarningKind>{};
  final tagPattern = RegExp(r"\[/?.[^\]]*\]");
  final parenthesesPattern = RegExp(r"\([^)]*\)");
  final doubleBracesPattern = RegExp(r"\{\{[^}]*\}\}");
  for (final line in rawLines) {
    if (tagPattern.hasMatch(line)) kinds.add(PersonalDslWarningKind.tags);
    if (line.contains("~")) kinds.add(PersonalDslWarningKind.tilde);
    if (parenthesesPattern.hasMatch(line)) {
      kinds.add(PersonalDslWarningKind.parentheses);
    }
    if (doubleBracesPattern.hasMatch(line)) {
      kinds.add(PersonalDslWarningKind.doubleBraces);
    }
  }
  return kinds;
}

bool _isGzip(Uint8List bytes) =>
    bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B;

/// Decodes text by BOM: UTF-32 LE/BE, UTF-8, UTF-16 LE/BE, and plain
/// UTF-8 when there is no BOM — unless the bytes show the NUL interleave
/// of BOM-less UTF-16 (see [_sniffUtf16]). The UTF-32 check comes before
/// UTF-16 LE: its BOM starts with the UTF-16 LE BOM.
String _decodeText(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xFE &&
      bytes[2] == 0x00 &&
      bytes[3] == 0x00) {
    return _decodeUtf32(bytes.sublist(4), littleEndian: true);
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x00 &&
      bytes[1] == 0x00 &&
      bytes[2] == 0xFE &&
      bytes[3] == 0xFF) {
    return _decodeUtf32(bytes.sublist(4), littleEndian: false);
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3));
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: false);
  }
  final sniffedLittleEndian = _sniffUtf16(bytes);
  if (sniffedLittleEndian != null) {
    return _decodeUtf16(bytes, littleEndian: sniffedLittleEndian);
  }
  return utf8.decode(bytes);
}

/// Sniffs BOM-less UTF-16: ASCII-range UTF-16 text leaves a NUL byte in
/// every other position (odd positions for LE, even positions for BE),
/// which plain UTF-8 text essentially never does. Returns true for LE,
/// false for BE, null when no such interleave is detected.
bool? _sniffUtf16(Uint8List bytes) {
  final sampleLength = bytes.length.clamp(0, 1024);
  if (sampleLength < 4) return null;
  var evenNulls = 0;
  var oddNulls = 0;
  var evenTotal = 0;
  var oddTotal = 0;
  for (var i = 0; i < sampleLength; i++) {
    if (i.isEven) {
      evenTotal++;
      if (bytes[i] == 0) evenNulls++;
    } else {
      oddTotal++;
      if (bytes[i] == 0) oddNulls++;
    }
  }
  // Require a clear interleave: many NULs on one side, few on the other.
  if (oddNulls >= 2 &&
      oddNulls / oddTotal >= 0.3 &&
      oddNulls >= evenNulls * 4) {
    return true;
  }
  if (evenNulls >= 2 &&
      evenNulls / evenTotal >= 0.3 &&
      evenNulls >= oddNulls * 4) {
    return false;
  }
  return null;
}

String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
  final data = ByteData.sublistView(bytes);
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(data.getUint16(i, littleEndian ? Endian.little : Endian.big));
  }
  return String.fromCharCodes(units);
}

String _decodeUtf32(Uint8List bytes, {required bool littleEndian}) {
  final data = ByteData.sublistView(bytes);
  final runes = <int>[];
  for (var i = 0; i + 3 < bytes.length; i += 4) {
    runes.add(data.getUint32(i, littleEndian ? Endian.little : Endian.big));
  }
  return String.fromCharCodes(runes);
}

/// Converts a Markdown body to the tag-free DSL subset, one output line per
/// input line. A blank output line stays blank so paragraph breaks survive
/// an export/import round-trip (the exporter re-indents them).
List<String> _markdownToDslLines(String body) {
  final lines = <String>[];
  var inFence = false;
  for (final rawLine in body.split("\n")) {
    final line = rawLine.trimRight();
    if (line.trimLeft().startsWith("```") ||
        line.trimLeft().startsWith("~~~")) {
      // Fence markers are Markdown syntax, not content; the fenced lines
      // themselves are kept verbatim below.
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      lines.add(line);
      continue;
    }
    if (line.trim().isEmpty) {
      lines.add("");
      continue;
    }
    lines.add(_markdownLineToDsl(line));
  }
  return lines;
}

String _markdownLineToDsl(String line) {
  var text = line.trimLeft();
  // Headings and blockquotes carry no DSL equivalent: keep their text.
  text = text.replaceFirst(RegExp(r"^#{1,6}\s+"), "");
  text = text.replaceFirst(RegExp(r"^>\s?"), "");
  // Horizontal rules separate sections; keep the break as a blank line.
  if (RegExp(r"^([-*_]\s*){3,}$").hasMatch(text)) return "";
  // List items become [m1] lines.
  final listMatch = RegExp(r"^[-*+]\s+(.*)$").firstMatch(text);
  final orderedMatch = RegExp(r"^\d+[.)]\s+(.*)$").firstMatch(text);
  final item = listMatch?.group(1) ?? orderedMatch?.group(1);
  if (item != null) return "[m1]${_markdownInlineToDsl(item)}[/m]";
  return _markdownInlineToDsl(text);
}

String _markdownInlineToDsl(String text) {
  var result = text;
  // Images keep their alt text; links keep their label. The target may
  // contain one level of nested parentheses, e.g. `...(Tea_(meal))`.
  result = result.replaceAllMapped(
    RegExp(r"!\[([^\]]*)\]\((?:[^()]|\([^()]*\))*\)"),
    (m) => m.group(1)!,
  );
  result = result.replaceAllMapped(
    RegExp(r"\[([^\]]*)\]\((?:[^()]|\([^()]*\))*\)"),
    (m) => m.group(1)!,
  );
  // Bold first, so `**x**` is not read as italic `*x*`. The bold body
  // may itself contain single-`*` italic, so it is matched with an
  // alternation that lets `*...*` through instead of `[^*]+`.
  result = result.replaceAllMapped(
    RegExp(r"\*\*((?:[^*]|\*[^*]+\*)+)\*\*"),
    (m) => "[b]${m.group(1)}[/b]",
  );
  result = result.replaceAllMapped(
    RegExp(r"__([^_]+)__"),
    (m) => "[b]${m.group(1)}[/b]",
  );
  result = result.replaceAllMapped(
    RegExp(r"\*([^*]+)\*"),
    (m) => "[i]${m.group(1)}[/i]",
  );
  // Inline code and strikethrough have no DSL equivalent: plain text.
  result = result.replaceAllMapped(RegExp(r"`([^`]*)`"), (m) => m.group(1)!);
  result = result.replaceAllMapped(RegExp(r"~~([^~]+)~~"), (m) => m.group(1)!);
  // Autolinks keep their URL as plain text; the HTML cleanup below would
  // otherwise delete the whole `<https://...>` token.
  result = result.replaceAllMapped(
    RegExp(r"<(https?://[^>\s]+)>"),
    (m) => m.group(1)!,
  );
  // Remaining HTML tags and backslash escapes are syntax, not content.
  result = result.replaceAll(RegExp("<[^>]*>"), "");
  result = result.replaceAllMapped(
    RegExp(r"\\([\\`*_{}\[\]()#+\-.!])"),
    (m) => m.group(1)!,
  );
  return result;
}

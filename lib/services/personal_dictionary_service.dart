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
import "package:drift/native.dart" show SqliteException;

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
      PersonalDslWarningKind.atReference =>
        l10n.personalDictionaryImportWarningAtReference,
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
  atReference,
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
///
/// [isEmptyInput] is true only when the imported text had no content at
/// all (empty or whitespace-only). It is the service-level empty-input
/// signal (P2-17): the UI shows the "file is empty" message for it
/// instead of "Imported 0 entries". A file with content but zero stored
/// entries — metadata-only, or every entry skipped with warnings — leaves
/// it false, so the caller can tell "nothing to import" apart from "the
/// import found entries but could not store any".
class PersonalDslImportResult {
  final int imported;
  final List<PersonalDslWarning> warnings;
  final bool isEmptyInput;

  const PersonalDslImportResult({
    required this.imported,
    this.warnings = const [],
    this.isEmptyInput = false,
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

  /// Called with the dictionary id after [deleteDictionary] has removed
  /// the dictionary, so the caller can drop state that lives outside this
  /// database — the full-text index, for example. Kept a callback (rather
  /// than importing the full-text service) so this service stays free of
  /// the search stack: the provider wires it to
  /// `FullTextSearchService.dropDictionary`. A failure here must not fail
  /// the delete itself — the dictionary is already gone — so it is
  /// swallowed. Group membership needs no hook: it lives in this database
  /// and is cleaned up inside the delete transaction.
  final Future<void> Function(int dictionaryId)? onDictionaryDeleted;

  PersonalDictionaryService(this.db, {this.onDictionaryDeleted});

  DictionaryListDao get _dictionaryListDao => DictionaryListDao(db);

  DictGroupDao get _dictGroupDao => DictGroupDao(db);

  PersonalDictionaryDao get _dao => PersonalDictionaryDao(db);

  /// Throws unless [id] is the id of a personal dictionary: a readable
  /// [StateError] for a missing row or a row of another type, never
  /// Drift's `Bad state: No element` from a bare `getSingle()` (P2-10).
  Future<void> _requirePersonalDictionary(int id) async {
    final row = await _dictionaryListDao.getById(id);
    if (row == null) {
      throw StateError("Personal dictionary $id not found");
    }
    if (row.type != DictionaryType.personal) {
      throw StateError(
        "Dictionary $id is not a personal dictionary (type ${row.type})",
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
    // Both writes in one transaction (P2-3): a failure between the insert
    // and the sentinel write-back used to leave a `path=""` orphan row.
    return db.transaction(() async {
      final id = await _dictionaryListDao.add(
        "",
        title,
        type: DictionaryType.personal,
      );
      await _dictionaryListDao.updatePath(id, "personal:$id");
      return id;
    });
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
    // Data, list row and group membership in one transaction (P2-3,
    // P2-4): a failure mid-delete used to leave a 0-entry row, and group
    // cleanup used to live only in the UI, so any other caller left the
    // deleted id behind in its groups. The full-text index lives outside
    // this database; [onDictionaryDeleted] drops it after the transaction
    // commits (personal dictionaries never have index rows, so the drop
    // is a no-op for them today — the hook keeps the delete correct if
    // that ever changes, and the UI still drops it as well).
    await db.transaction(() async {
      await _dao.deleteDictionaryData(id);
      await _dictionaryListDao.removeById(id);
      await _dictGroupDao.removeDictIdFromAllGroups(id);
    });
    final hook = onDictionaryDeleted;
    if (hook != null) {
      try {
        await hook(id);
      } catch (_) {
        // The dictionary is already gone; a stale-index cleanup failure
        // must not report the delete itself as failed.
      }
    }
  }

  /// Entries of [dictionaryId], in normalized-headword order. With
  /// [query], only entries with a headword starting with the normalized
  /// query, at most [PersonalDictionaryDao]’s filtered limit — the
  /// matching is done in SQL, and each matched entry comes back with
  /// *all* of its headwords, not just the matching alias (P2-9, P2-19):
  /// a filtered view must show every alias of a matched entry.
  Future<List<PersonalEntry>> listEntries(
    int dictionaryId, {
    String? query,
  }) async {
    await _requirePersonalDictionary(dictionaryId);
    final normalizedPrefix = query == null || query.trim().isEmpty
        ? null
        : normalizePersonalHeadword(query.trim());
    if (normalizedPrefix != null) {
      final articleIds = await _dao.articleIdsForHeadwordPrefix(
        dictionaryId,
        normalizedPrefix,
      );
      if (articleIds.isEmpty) return [];
      final articles = await _dao.articlesByIds(articleIds);
      final headwords = await _dao.headwordsForArticles(articleIds);
      final headwordsByArticle = <int, List<String>>{};
      for (final headword in headwords) {
        (headwordsByArticle[headword.articleId] ??= []).add(headword.headword);
      }
      final articleById = {for (final article in articles) article.id: article};
      return [
        for (final articleId in articleIds)
          if (articleById[articleId] != null)
            PersonalEntry(
              articleId: articleId,
              dictionaryId: dictionaryId,
              headwords: headwordsByArticle[articleId] ?? const [],
              body: articleById[articleId]!.body,
              updatedAt: articleById[articleId]!.updatedAt,
            ),
      ];
    }
    final headwords = await _dao.headwordsForDictionary(dictionaryId);
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

  Future<int> entryCount(int dictionaryId) async {
    await _requirePersonalDictionary(dictionaryId);
    return _dao.countArticles(dictionaryId);
  }

  /// Creates one article filed under [headwords] (aliases sharing the
  /// article) and returns the article id.
  ///
  /// Headwords are trimmed, empties dropped and duplicates (after
  /// normalisation) collapsed; an empty headword list or an empty body is
  /// an error, as is a headword that already belongs to another article of
  /// this dictionary. The body is stored trimmed (P2-20), so the same
  /// entry written through the UI editor and through the service or an
  /// import comes out identical.
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
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      throw ArgumentError("Entry body must not be empty");
    }
    // The duplicate check runs inside the same transaction as the insert
    // (P2-1): checked outside, two concurrent creates could both pass
    // the check and the loser would leak the raw SQLite UNIQUE error.
    // The check alone still cannot close the race under a deferred
    // transaction, so a UNIQUE failure from the insert itself is
    // translated to the same StateError below.
    return _translateUniqueViolation(() {
      return db.transaction(() async {
        await _requireHeadwordsFree(dictionaryId, cleaned);
        final now = DateTime.now();
        final articleId = await _dao.insertArticle(
          PersonalArticlesCompanion(
            dictionaryId: Value(dictionaryId),
            body: Value(trimmedBody),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await _dao.insertHeadwords(
          _headwordCompanions(dictionaryId, articleId, cleaned),
        );
        return articleId;
      });
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
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      throw ArgumentError("Entry body must not be empty");
    }
    return _translateUniqueViolation(() {
      return db.transaction(() async {
        await _requireHeadwordsFree(
          article.dictionaryId,
          cleaned,
          exceptArticleId: articleId,
        );
        await _dao.updateArticle(
          articleId,
          PersonalArticlesCompanion(
            body: Value(trimmedBody),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _dao.replaceHeadwords(
          articleId,
          _headwordCompanions(article.dictionaryId, articleId, cleaned),
        );
      });
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
    // Identical skip warnings are reported once (P2-13): a file that
    // repeats the same duplicate headword three times produces one
    // warning, not three, so the warnings dialog stays bounded.
    void addWarningOnce(PersonalDslWarning warning) {
      if (!warnings.contains(warning)) warnings.add(warning);
    }

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
      for (final kind in _dslWarningKinds(article.bodyRawLines)) {
        if (warnedKinds.add(kind)) warnings.add(PersonalDslWarning(kind));
      }
      if (article.body.trim().isEmpty) {
        addWarningOnce(
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
        // a duplicate and still aborts. The warning is the localised
        // duplicate kind, never the raw exception text (P2-13).
        if (!e.message.contains("already exists")) rethrow;
        addWarningOnce(
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
        addWarningOnce(
          PersonalDslWarning(PersonalDslWarningKind.invalidEntry, display),
        );
      }
    }
    return PersonalDslImportResult(
      imported: imported,
      warnings: warnings,
      isEmptyInput: content.trim().isEmpty,
    );
  }

  /// Imports DSL from raw bytes: gunzips when [filename] ends with `.dz`
  /// or the bytes carry the gzip magic, then decodes by BOM (UTF-8/16/32
  /// LE/BE, otherwise UTF-8) and imports as [importDsl].
  ///
  /// A decode or decompress failure throws a [FormatException] that names
  /// [filename] and what was being attempted, with the underlying decoder
  /// error kept in the message (P2-18) — never the bare Dart/zlib text.
  /// The UI reports it through the localised generic-operation-failed
  /// toast, so no new l10n string is needed for it.
  Future<PersonalDslImportResult> importDslBytes(
    int dictionaryId,
    Uint8List bytes,
    String filename,
  ) async {
    var data = bytes;
    if (filename.toLowerCase().endsWith(".dz") || _isGzip(data)) {
      try {
        data = Uint8List.fromList(gzip.decode(data));
      } catch (e) {
        throw FormatException(
          "Could not decompress $filename as gzip (.dz): $e",
        );
      }
    }
    late final String text;
    try {
      text = _decodeText(data);
    } catch (e) {
      throw FormatException(
        "Could not read $filename as text (UTF-8/UTF-16/UTF-32): $e",
      );
    }
    return importDsl(dictionaryId, text);
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

  /// Runs [action], translating a SQLite UNIQUE constraint failure on
  /// the personal-headwords index into the same `StateError("... already
  /// exists")` the pre-check throws, so concurrent creates (P2-1) and
  /// `importDsl` — which only catches `StateError` — see one consistent
  /// duplicate error instead of a raw `SqliteException(2067)`.
  Future<T> _translateUniqueViolation<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SqliteException catch (e) {
      if (e.extendedResultCode == 2067 ||
          e.message.contains("UNIQUE constraint failed")) {
        throw StateError("Headword already exists in this dictionary");
      }
      rethrow;
    }
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
/// lines, dedented, joined with `\n`), and the body lines exactly as
/// written in the file (indentation intact), used for the DSL-construct
/// warnings. Headword lines are never included there: a parenthesis in a
/// headword is not body text (P2-14).
class _DslArticle {
  final List<String> headwords;
  final String body;
  final List<String> bodyRawLines;

  const _DslArticle({
    required this.headwords,
    required this.body,
    required this.bodyRawLines,
  });
}

/// Splits DSL text into articles: a non-indented line is a headword, the
/// indented lines after it are the article body. A blank line ends the
/// current article, and so does a headword line after body lines.
///
/// A blank line inside a body is kept as an empty body line (a paragraph
/// break), not an article separator — including blank lines at the very
/// start or end of a body, which `flush()` no longer trims (P2-12):
/// dropping them broke the export/import round-trip. The store layer
/// still trims bodies on write (P2-20), so leading/trailing blank lines
/// are normalised away at the first import; from then on the round-trip
/// is stable. Lines starting with `#` before any headword has been
/// collected are DSL metadata (`#NAME`, `#INDEX_LANGUAGE`, ...) or
/// comments, not headwords; indented body lines (such as a Markdown
/// heading) are never treated as metadata. A body line with no headword
/// above it is skipped and recorded in [skippedOrphanBodyLines] instead
/// of failing the whole import.
///
/// Body indentation is dedented, not stripped: only the minimal common
/// indent across the article's body lines is removed (P2-11), so nested
/// levels keep their relative depth instead of being flattened to one.
List<_DslArticle> _parseDsl(
  String content, {
  List<String>? skippedOrphanBodyLines,
}) {
  final articles = <_DslArticle>[];
  var headwords = <String>[];
  var bodyLines = <String>[];
  var hasBody = false;

  void flush() {
    if (headwords.isEmpty) return;
    articles.add(
      _DslArticle(
        headwords: List.of(headwords),
        body: _dedentBodyLines(bodyLines).join("\n"),
        bodyRawLines: List.of(bodyLines),
      ),
    );
    headwords = [];
    bodyLines = [];
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
      bodyLines.add(line);
    } else {
      if (hasBody) flush();
      headwords.add(line.trim());
    }
  }
  flush();
  return articles;
}

/// Removes only the minimal common indent across [lines] (dedent-style):
/// the longest leading-whitespace prefix shared by every non-blank line.
/// Blank lines are left empty. Unlike stripping all leading whitespace,
/// this keeps nested levels distinct — a body indented 4/8/4 spaces comes
/// back as 0/4/0, not 0/0/0 (P2-11).
List<String> _dedentBodyLines(List<String> lines) {
  var prefix = "";
  var found = false;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final indent = line.substring(0, line.length - line.trimLeft().length);
    if (!found) {
      prefix = indent;
      found = true;
    } else {
      var i = 0;
      while (i < prefix.length && i < indent.length && prefix[i] == indent[i]) {
        i++;
      }
      prefix = prefix.substring(0, i);
    }
    if (prefix.isEmpty) break;
  }
  if (prefix.isEmpty) return List.of(lines);
  return [
    for (final line in lines)
      line.startsWith(prefix) ? line.substring(prefix.length) : line,
  ];
}

/// DSL constructs this dictionary keeps as plain text, each reported once
/// per import. Only body lines are scanned (P2-14): headword lines are
/// never passed in, so a parenthesis in a headword cannot warn.
Set<PersonalDslWarningKind> _dslWarningKinds(List<String> bodyLines) {
  final kinds = <PersonalDslWarningKind>{};
  final tagPattern = RegExp(r"\[/?.[^\]]*\]");
  final parenthesesPattern = RegExp(r"\([^)]*\)");
  final doubleBracesPattern = RegExp(r"\{\{[^}]*\}\}");
  // An @-prefixed word at the start of a body line or after whitespace,
  // e.g. `@see banana`: stored as plain text, not a cross-reference
  // (P2-15). An @ inside a word (an email address) does not count.
  final atReferencePattern = RegExp(r"(^|\s)@\w+");
  for (final line in bodyLines) {
    if (tagPattern.hasMatch(line)) kinds.add(PersonalDslWarningKind.tags);
    if (line.contains("~")) kinds.add(PersonalDslWarningKind.tilde);
    if (parenthesesPattern.hasMatch(line)) {
      kinds.add(PersonalDslWarningKind.parentheses);
    }
    if (doubleBracesPattern.hasMatch(line)) {
      kinds.add(PersonalDslWarningKind.doubleBraces);
    }
    if (atReferencePattern.hasMatch(line)) {
      kinds.add(PersonalDslWarningKind.atReference);
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
  // Single-underscore emphasis `_x_` is italic too (P2-16). The
  // underscores must sit next to non-word characters, so intra-word
  // underscores in identifiers such as `snake_case` survive untouched;
  // the content may not contain underscores or start/end with a space.
  result = result.replaceAllMapped(
    RegExp(r"(?<!\w)_([^_\s][^_]*[^_\s]|[^_\s])_(?!\w)"),
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

import "dart:io";

import "package:ciyue/services/full_text_search.dart";
import "package:drift/drift.dart";
import "package:drift/native.dart";

/// Schema version of the per-dictionary FTS5 tables.
///
/// Bump when the table shape changes. The version is stamped into the
/// fingerprint ([FullTextSearchService.fingerprintFor]), so existing users'
/// indexes rebuild instead of keeping tables without the new columns —
/// without that, a suffix query would throw "no such column", which the
/// service swallows per dictionary and suffix mode would come back
/// silently empty for everyone who already had an index.
///
/// v2 adds the `headword_rev` column (suffix search).
const int fullTextIndexSchemaVersion = 2;

/// One indexed entry: the row id is the entry's ordinal in the dictionary's
/// iteration order (1-based), which is what makes a cancelled build
/// resumable — rebuilding skips the rows already stored.
///
/// The builder isolate precomputes the derived columns ([headwordRev] and
/// the three tokenized columns) so the main isolate never pays the
/// per-rune tokenization of a whole batch: [FullTextIndexStore.insertBatch]
/// only falls back to computing them inline when they are absent (raw rows
/// from tests and ad-hoc callers).
class FullTextIndexRow {
  final int rowid;
  final String headword;

  /// Plain text of the entry, HTML already stripped.
  final String body;

  /// The headword reversed by rune, as stored in the `headword_rev`
  /// column. Computed from [headword] when absent.
  final String? headwordRev;

  /// Pre-tokenized text for the FTS5 table, as produced by
  /// [tokenizeForIndex] in the builder isolate. Absent rows are tokenized
  /// by [FullTextIndexStore.insertBatch] instead.
  final String? headwordTokenized;
  final String? headwordRevTokenized;
  final String? bodyTokenized;

  const FullTextIndexRow({
    required this.rowid,
    required this.headword,
    required this.body,
    this.headwordRev,
    this.headwordTokenized,
    this.headwordRevTokenized,
    this.bodyTokenized,
  });
}

enum FullTextIndexDbState { building, ready, failed }

class FullTextIndexMeta {
  final int dictionaryId;
  final String fingerprint;
  final int total;
  final int indexed;
  final FullTextIndexDbState state;

  const FullTextIndexMeta({
    required this.dictionaryId,
    required this.fingerprint,
    required this.total,
    required this.indexed,
    required this.state,
  });
}

class FullTextHit {
  final int dictionaryId;
  final String headword;

  /// `snippet()` output with [snippetMatchStart]/[snippetMatchEnd] markers
  /// around matches; see [parseSnippet].
  final String snippet;
  final double rank;

  const FullTextHit({
    required this.dictionaryId,
    required this.headword,
    required this.snippet,
    required this.rank,
  });
}

class _FtsDatabase extends GeneratedDatabase {
  _FtsDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  List<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
}

/// SQLite FTS5 store for per-dictionary full-text indexes.
///
/// One shared database file (rebuildable cache data, next to the `.cidx`
/// files) holds one FTS5 virtual table per dictionary, backed by an external
/// content table holding the original plain text so `snippet()` returns
/// readable text: the FTS table itself only stores tokens of the
/// [tokenizeForIndex]-preprocessed text.
///
/// FTS5 virtual tables cannot be expressed as drift tables, so this store
/// uses raw statements through a table-less [GeneratedDatabase]. The app
/// database is untouched: no migration, no schema churn.
///
/// The database runs in a drift background isolate
/// ([NativeDatabase.createInBackground]): every statement — queries and
/// writes alike — executes off the main isolate, so a 150ms common-word
/// query or a 500-row batch write never blocks the UI thread. SELECTs are
/// spread over a pool of reader isolates ([_readPoolSize]), so concurrent
/// queries for several dictionaries run in parallel instead of queueing
/// behind each other on one connection; writes stay on the worker isolate.
/// WAL mode is what lets readers proceed while a build holds a write
/// transaction.
class FullTextIndexStore {
  final _FtsDatabase _db;
  bool _metaReady = false;

  /// Reader isolates for SELECTs. Three is enough for the usual group
  /// (a handful of dictionaries) without spawning an isolate per
  /// dictionary; each idle isolate costs little more than a thread and a
  /// SQLite connection.
  static const int _readPoolSize = 3;

  FullTextIndexStore(QueryExecutor executor) : _db = _FtsDatabase(executor);

  /// Opens the store on [file], creating it when missing.
  ///
  /// Runs [NativeDatabase.createInBackground], so the returned store's
  /// statements execute in drift's worker isolate (plus [ _readPoolSize]
  /// reader isolates); closing the store shuts those isolates down.
  /// [setup] runs on every isolate that opens the file.
  static Future<FullTextIndexStore> openFile(File file) async {
    final store = FullTextIndexStore(
      NativeDatabase.createInBackground(
        file,
        readPool: _readPoolSize,
        setup: (db) {
          // busy_timeout first: it is connection-local (no lock), and it
          // lets the write-lock statements below wait out a concurrent
          // reader instead of failing with SQLITE_BUSY when several
          // isolates open the file at once. This timeout is part of the
          // multi-connection architecture, not a tuning knob.
          db.execute("PRAGMA busy_timeout=5000;");
          // auto_vacuum MUST come before journal_mode: switching the
          // journal mode writes the database header, after which an
          // auto_vacuum change is silently ignored (probe: WAL-first
          // reads back 0, FULL-first reads back 1). The flag is only
          // recorded while the database is still empty; existing
          // databases pick it up through the VACUUM in [dropDictionary].
          // Only set when unset: every isolate runs this setup, and a
          // repeat set would take a write lock on every open.
          try {
            final current = db.select("PRAGMA auto_vacuum;");
            if (current.first["auto_vacuum"] != 1) {
              db.execute("PRAGMA auto_vacuum=FULL;");
            }
          } catch (_) {
            // A concurrent connection holds the write lock, or the file
            // predates the flag: the index still works, and the
            // dropDictionary VACUUM path retries.
          }
          db.execute("PRAGMA journal_mode=WAL;");
          db.execute("PRAGMA synchronous=NORMAL;");
        },
      ),
    );
    // `createInBackground` is lazy: nothing opens the file until the first
    // statement. Force the open here, as the old direct `NativeDatabase`
    // constructor plus its `PRAGMA synchronous` did, so the setup above
    // (WAL, auto_vacuum) has run before this returns and a second
    // connection reads the persisted pragmas instead of fresh defaults.
    await store._db.customStatement("PRAGMA synchronous = NORMAL");
    return store;
  }

  String _contentTable(int dictionaryId) => "fts_content_$dictionaryId";
  String _ftsTable(int dictionaryId) => "fts_$dictionaryId";

  Future<void> _ensureMeta() async {
    if (_metaReady) return;
    await _db.customStatement(
      "CREATE TABLE IF NOT EXISTS fts_meta ("
      "dictionary_id INTEGER PRIMARY KEY, "
      "fingerprint TEXT NOT NULL, "
      "total INTEGER NOT NULL DEFAULT 0, "
      "indexed INTEGER NOT NULL DEFAULT 0, "
      "state TEXT NOT NULL DEFAULT 'building', "
      "updated_at INTEGER NOT NULL)",
    );
    _metaReady = true;
  }

  /// Creates (or recreates, when [fingerprint] differs) the tables for
  /// [dictionaryId]. Returns false when a ready index with the same
  /// fingerprint already exists and nothing needs rebuilding. When the
  /// fingerprint matches but a previous build never finished, the partial
  /// tables are kept so the next build resumes instead of restarting.
  Future<bool> ensureDictionary(int dictionaryId, String fingerprint) async {
    await _ensureMeta();
    var rebuild = true;
    await _db.transaction(() async {
      final existing = await _db
          .customSelect(
            "SELECT fingerprint, state FROM fts_meta WHERE dictionary_id = ?",
            variables: [Variable.withInt(dictionaryId)],
          )
          .getSingleOrNull();
      if (existing != null &&
          existing.read<String>("fingerprint") == fingerprint) {
        if (existing.read<String>("state") == FullTextIndexDbState.ready.name) {
          rebuild = false;
          return;
        }
        // Resume a partial build, but only when its tables survived: a
        // half-cleared cache must fall through to a clean rebuild instead
        // of failing forever on missing tables.
        final content = _contentTable(dictionaryId);
        final tables = await _db
            .customSelect(
              "SELECT COUNT(*) AS n FROM sqlite_master WHERE name IN (?, ?)",
              variables: [
                Variable.withString(content),
                Variable.withString(_ftsTable(dictionaryId)),
              ],
            )
            .getSingle();
        if (tables.read<int>("n") == 2) {
          await _db.customStatement(
            "UPDATE fts_meta SET state = 'building', updated_at = ? "
            "WHERE dictionary_id = ?",
            [DateTime.now().millisecondsSinceEpoch, dictionaryId],
          );
          return;
        }
      }
      final content = _contentTable(dictionaryId);
      final fts = _ftsTable(dictionaryId);
      await _db.customStatement("DROP TABLE IF EXISTS $fts");
      await _db.customStatement("DROP TABLE IF EXISTS $content");
      await _db.customStatement(
        "CREATE TABLE $content ("
        "rowid INTEGER PRIMARY KEY, "
        "headword TEXT NOT NULL, "
        "headword_rev TEXT NOT NULL, "
        "body TEXT NOT NULL)",
      );
      // The external content table and the FTS5 table must carry the same
      // columns. `headword_rev` is the headword reversed by rune (see
      // [reverseHeadword]): suffix search is a prefix MATCH on it.
      await _db.customStatement(
        "CREATE VIRTUAL TABLE $fts USING fts5("
        "headword, headword_rev, body, "
        "content='$content', content_rowid='rowid', "
        "tokenize='unicode61')",
      );
      await _db.customStatement(
        "INSERT INTO fts_meta "
        "(dictionary_id, fingerprint, total, indexed, state, updated_at) "
        "VALUES (?, ?, 0, 0, 'building', ?) "
        "ON CONFLICT(dictionary_id) DO UPDATE SET "
        "fingerprint=excluded.fingerprint, total=0, indexed=0, "
        "state='building', updated_at=excluded.updated_at",
        [dictionaryId, fingerprint, DateTime.now().millisecondsSinceEpoch],
      );
    });
    return rebuild;
  }

  /// Rows per multi-value INSERT statement. 500 rows bind 2000 variables,
  /// far below SQLITE_MAX_VARIABLE_NUMBER on every supported build (a
  /// single 100k-row statement fails to prepare in a probe).
  static const int _insertChunkRows = 500;

  static String _multiInsertSql(String table, int rowCount) {
    final sql = StringBuffer(
      "INSERT OR REPLACE INTO $table "
      "(rowid, headword, headword_rev, body) VALUES ",
    );
    for (var i = 0; i < rowCount; i++) {
      if (i > 0) sql.write(", ");
      sql.write("(?, ?, ?, ?)");
    }
    return sql.toString();
  }

  /// Appends [rows] to the index, updating the stored progress to
  /// [indexed] (the highest row id stored so far).
  ///
  /// One multi-value INSERT per table per chunk instead of two drift calls
  /// per row: a 500-row batch used to be 1000 round-trips to the database,
  /// now it is 2 (plus the meta update). The rows are written with their
  /// explicit row ids into the content table first and then into the FTS5
  /// table, so `content_rowid` stays consistent exactly as with the old
  /// row-by-row writes; the tests compare both spellings.
  ///
  /// Tokenization itself runs in the builder isolate for build batches
  /// (see [FullTextIndexRow]): the tokenized columns travel with the row
  /// and are used as-is. Rows without them are tokenized here, so callers
  /// that build rows by hand keep working.
  Future<void> insertBatch(
    int dictionaryId,
    List<FullTextIndexRow> rows,
    int indexed,
  ) async {
    if (rows.isEmpty) return;
    await _ensureMeta();
    final content = _contentTable(dictionaryId);
    final fts = _ftsTable(dictionaryId);
    await _db.transaction(() async {
      for (var start = 0; start < rows.length; start += _insertChunkRows) {
        final end = (start + _insertChunkRows).clamp(0, rows.length);
        final chunk = rows.sublist(start, end);
        final contentValues = <Object?>[];
        final ftsValues = <Object?>[];
        for (final row in chunk) {
          final headwordRev = row.headwordRev ?? reverseHeadword(row.headword);
          contentValues.addAll([
            row.rowid,
            row.headword,
            headwordRev,
            row.body,
          ]);
          ftsValues.addAll([
            row.rowid,
            row.headwordTokenized ?? tokenizeForIndex(row.headword),
            row.headwordRevTokenized ?? tokenizeForIndex(headwordRev),
            row.bodyTokenized ?? tokenizeForIndex(row.body),
          ]);
        }
        await _db.customStatement(
          _multiInsertSql(content, chunk.length),
          contentValues,
        );
        await _db.customStatement(
          _multiInsertSql(fts, chunk.length),
          ftsValues,
        );
      }
      await _db.customStatement(
        "UPDATE fts_meta SET indexed = ?, "
        "updated_at = ? WHERE dictionary_id = ?",
        [indexed, DateTime.now().millisecondsSinceEpoch, dictionaryId],
      );
    });
  }

  Future<void> setTotal(int dictionaryId, int total) async {
    await _ensureMeta();
    await _db.customStatement(
      "UPDATE fts_meta SET total = ?, updated_at = ? "
      "WHERE dictionary_id = ?",
      [total, DateTime.now().millisecondsSinceEpoch, dictionaryId],
    );
  }

  /// Marks the index ready. [total] is the dictionary's entry count; the
  /// stored `indexed` count is left untouched because entries with empty
  /// bodies are skipped during the build, so it is usually smaller.
  Future<void> markComplete(int dictionaryId, int total) async {
    await _ensureMeta();
    await _db.customStatement(
      "UPDATE fts_meta SET total = ?, state = 'ready', "
      "updated_at = ? WHERE dictionary_id = ?",
      [total, DateTime.now().millisecondsSinceEpoch, dictionaryId],
    );
  }

  Future<void> markFailed(int dictionaryId) async {
    await _ensureMeta();
    await _db.customStatement(
      "UPDATE fts_meta SET state = 'failed', updated_at = ? "
      "WHERE dictionary_id = ?",
      [DateTime.now().millisecondsSinceEpoch, dictionaryId],
    );
  }

  Future<FullTextIndexMeta?> meta(int dictionaryId) async {
    await _ensureMeta();
    final row = await _db
        .customSelect(
          "SELECT dictionary_id, fingerprint, total, indexed, state "
          "FROM fts_meta WHERE dictionary_id = ?",
          variables: [Variable.withInt(dictionaryId)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return FullTextIndexMeta(
      dictionaryId: row.read<int>("dictionary_id"),
      fingerprint: row.read<String>("fingerprint"),
      total: row.read<int>("total"),
      indexed: row.read<int>("indexed"),
      state: FullTextIndexDbState.values.byName(row.read<String>("state")),
    );
  }

  Future<List<FullTextIndexMeta>> allMeta() async {
    await _ensureMeta();
    final rows = await _db
        .customSelect(
          "SELECT dictionary_id, fingerprint, total, indexed, state "
          "FROM fts_meta",
        )
        .get();
    return [
      for (final row in rows)
        FullTextIndexMeta(
          dictionaryId: row.read<int>("dictionary_id"),
          fingerprint: row.read<String>("fingerprint"),
          total: row.read<int>("total"),
          indexed: row.read<int>("indexed"),
          state: FullTextIndexDbState.values.byName(row.read<String>("state")),
        ),
    ];
  }

  /// Runs [matchExpression] (see [buildFtsMatchExpression]) against one
  /// dictionary's index, best rank first. Headword matches weigh 10x body
  /// matches via the `bm25` column weights; `headword_rev` weighs 0, so
  /// the reversed column never leaks into full-text ranking.
  Future<List<FullTextHit>> searchOne(
    int dictionaryId,
    String matchExpression, {
    int limit = 50,
  }) async {
    await _ensureMeta();
    final content = _contentTable(dictionaryId);
    final fts = _ftsTable(dictionaryId);
    final rows = await _db
        .customSelect(
          "SELECT c.headword AS headword, "
          "snippet($fts, 2, ?, ?, ?, ?) AS snippet, "
          "bm25($fts, 10.0, 0.0, 1.0) AS rank "
          "FROM $fts JOIN $content AS c ON c.rowid = $fts.rowid "
          "WHERE $fts MATCH ? ORDER BY rank LIMIT ?",
          variables: [
            Variable.withString(snippetMatchStart),
            Variable.withString(snippetMatchEnd),
            Variable.withString("…"),
            Variable.withInt(24),
            Variable.withString(matchExpression),
            Variable.withInt(limit),
          ],
        )
        .get();
    return [
      for (final row in rows)
        FullTextHit(
          dictionaryId: dictionaryId,
          headword: row.read<String>("headword"),
          snippet: row.read<String>("snippet"),
          rank: row.read<double>("rank"),
        ),
    ];
  }

  /// Suffix search on one dictionary's index: headwords ending with
  /// [query], best rank first.
  ///
  /// The MATCH is a prefix query on the reversed-headword column (see
  /// [buildSuffixMatchExpression]), which on its own also matches headwords
  /// that merely CONTAIN the query — FTS5 phrases match at any position —
  /// so hits are post-filtered with `headword.endsWith(query)`. Without
  /// that filter, suffix `主义` would also return `主义者`.
  ///
  /// The endsWith check is pushed into SQL as well, so `LIMIT` applies
  /// after filtering instead of before it: without the pushdown, a
  /// common CJK suffix (者/人/国) loses recall because the short
  /// containing-but-not-ending headwords fill all pre-filter slots.
  /// SQLite's `lower()` only folds ASCII, while the Dart filter folds
  /// all of Unicode, so the SQL condition is only a pre-screen — the
  /// Dart `endsWith` below stays as the final arbiter and is never
  /// dropped.
  Future<List<FullTextHit>> searchSuffixOne(
    int dictionaryId,
    String query, {
    int limit = 50,
  }) async {
    final expression = buildSuffixMatchExpression(query);
    if (expression.isEmpty) return const [];
    final hits = await _searchWithExpression(
      dictionaryId,
      expression,
      // Only the reversed column carries the match; the other columns
      // weigh 0 so they cannot reorder suffix hits.
      bm25Weights: "0.0, 1.0, 0.0",
      limit: limit,
      endsWithQuery: query,
    );
    final foldedQuery = query.toLowerCase();
    return [
      for (final hit in hits)
        if (hit.headword.toLowerCase().endsWith(foldedQuery)) hit,
    ];
  }

  /// Multi-word AND search on one dictionary's index: headwords containing
  /// every character/word of [query], in any order, best rank first.
  ///
  /// The MATCH is qualified to the headword column only (see
  /// [buildHeadwordAndMatchExpression]), so a body that mentions the query
  /// never matches — unlike [searchOne], which searches headword and body.
  Future<List<FullTextHit>> searchHeadwordAndOne(
    int dictionaryId,
    String query, {
    int limit = 50,
  }) async {
    final expression = buildHeadwordAndMatchExpression(query);
    if (expression.isEmpty) return const [];
    return _searchWithExpression(
      dictionaryId,
      expression,
      bm25Weights: "10.0, 0.0, 1.0",
      limit: limit,
    );
  }

  Future<List<FullTextHit>> _searchWithExpression(
    int dictionaryId,
    String matchExpression, {
    required String bm25Weights,
    required int limit,
    String? endsWithQuery,
  }) async {
    await _ensureMeta();
    final content = _contentTable(dictionaryId);
    final fts = _ftsTable(dictionaryId);
    final rows = await _db
        .customSelect(
          "SELECT c.headword AS headword, "
          "snippet($fts, 2, ?, ?, ?, ?) AS snippet, "
          "bm25($fts, $bm25Weights) AS rank "
          "FROM $fts JOIN $content AS c ON c.rowid = $fts.rowid "
          "WHERE $fts MATCH ? "
          "${endsWithQuery == null ? "" : "AND substr(lower(c.headword), -length(?)) = lower(?) "}"
          "ORDER BY rank LIMIT ?",
          variables: [
            Variable.withString(snippetMatchStart),
            Variable.withString(snippetMatchEnd),
            Variable.withString("…"),
            Variable.withInt(24),
            Variable.withString(matchExpression),
            if (endsWithQuery != null) ...[
              Variable.withString(endsWithQuery),
              Variable.withString(endsWithQuery),
            ],
            Variable.withInt(limit),
          ],
        )
        .get();
    return [
      for (final row in rows)
        FullTextHit(
          dictionaryId: dictionaryId,
          headword: row.read<String>("headword"),
          snippet: row.read<String>("snippet"),
          rank: row.read<double>("rank"),
        ),
    ];
  }

  /// Drops a dictionary's tables and meta row entirely, then reclaims the
  /// freed pages. The file does not shrink on its own: with
  /// `auto_vacuum=FULL` (set at [openFile]) the DROP frees the pages, but
  /// a database created before that flag existed only records the flag
  /// when it is vacuumed — so the VACUUM runs here, right after
  /// re-asserting the flag, which is exactly the sequence that records it.
  /// Best-effort: a concurrent reader can keep the database busy, in which
  /// case the space is reclaimed on the next drop and the index still
  /// works. Runs in the background isolate, so the (possibly ~1s) rewrite
  /// of a large index never blocks the UI.
  Future<void> dropDictionary(int dictionaryId) async {
    await _ensureMeta();
    await _db.customStatement(
      "DROP TABLE IF EXISTS ${_ftsTable(dictionaryId)}",
    );
    await _db.customStatement(
      "DROP TABLE IF EXISTS ${_contentTable(dictionaryId)}",
    );
    await _db.customStatement("DELETE FROM fts_meta WHERE dictionary_id = ?", [
      dictionaryId,
    ]);
    try {
      await _db.customStatement("PRAGMA auto_vacuum=FULL;");
      await _db.customStatement("VACUUM;");
    } catch (_) {
      // Reclaiming space is opportunistic; the drop above already
      // succeeded, and the next drop retries.
    }
  }

  /// On-disk size of one dictionary's index in bytes: the FTS5 virtual
  /// table's shadow tables plus the external content table. Uses `dbstat`
  /// when the SQLite build provides it; otherwise falls back to the stored
  /// text length, which understates the real size but stays meaningful.
  /// Returns 0 when the dictionary has no index.
  Future<int> indexSizeBytes(int dictionaryId) async {
    await _ensureMeta();
    final fts = _ftsTable(dictionaryId);
    final content = _contentTable(dictionaryId);
    try {
      final row = await _db
          .customSelect(
            "SELECT COALESCE(SUM(pgsize), 0) AS size FROM dbstat "
            "WHERE name IN (?, ?, ?, ?, ?, ?)",
            variables: [
              Variable.withString(fts),
              Variable.withString("${fts}_data"),
              Variable.withString("${fts}_idx"),
              Variable.withString("${fts}_content"),
              Variable.withString("${fts}_docsize"),
              Variable.withString(content),
            ],
          )
          .getSingleOrNull();
      if (row != null) return row.read<int>("size");
    } catch (_) {
      // dbstat unavailable in this SQLite build; fall through.
    }
    try {
      final row = await _db
          .customSelect(
            "SELECT COALESCE(SUM(LENGTH(headword) + LENGTH(body)), 0) "
            "AS size FROM $content",
          )
          .getSingleOrNull();
      if (row != null) return row.read<int>("size");
    } catch (_) {
      // No content table: no index.
    }
    return 0;
  }

  /// Drops indexes whose dictionary is no longer in [knownIds].
  Future<void> pruneExcept(Set<int> knownIds) async {
    for (final entry in await allMeta()) {
      if (!knownIds.contains(entry.dictionaryId)) {
        await dropDictionary(entry.dictionaryId);
      }
    }
  }

  Future<void> close() => _db.close();
}

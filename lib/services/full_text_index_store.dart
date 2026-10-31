import "dart:io";

import "package:ciyue/services/full_text_search.dart";
import "package:drift/drift.dart";
import "package:drift/native.dart";

/// One indexed entry: the row id is the entry's ordinal in the dictionary's
/// iteration order (1-based), which is what makes a cancelled build
/// resumable — rebuilding skips the rows already stored.
class FullTextIndexRow {
  final int rowid;
  final String headword;

  /// Plain text of the entry, HTML already stripped.
  final String body;

  const FullTextIndexRow({
    required this.rowid,
    required this.headword,
    required this.body,
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
class FullTextIndexStore {
  final _FtsDatabase _db;
  bool _metaReady = false;

  FullTextIndexStore(QueryExecutor executor) : _db = _FtsDatabase(executor);

  /// Opens the store on [file], creating it when missing.
  static Future<FullTextIndexStore> openFile(File file) async {
    final store = FullTextIndexStore(NativeDatabase(file));
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
        "body TEXT NOT NULL)",
      );
      await _db.customStatement(
        "CREATE VIRTUAL TABLE $fts USING fts5("
        "headword, body, "
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

  /// Appends [rows] to the index, updating the stored progress to
  /// [indexed] (the highest row id stored so far).
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
      for (final row in rows) {
        await _db.customStatement(
          "INSERT OR REPLACE INTO $content (rowid, headword, body) "
          "VALUES (?, ?, ?)",
          [row.rowid, row.headword, row.body],
        );
        await _db.customStatement(
          "INSERT OR REPLACE INTO $fts (rowid, headword, body) "
          "VALUES (?, ?, ?)",
          [
            row.rowid,
            tokenizeForIndex(row.headword),
            tokenizeForIndex(row.body),
          ],
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
  /// matches via the `bm25` column weights.
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
          "snippet($fts, 1, ?, ?, ?, ?) AS snippet, "
          "bm25($fts, 10.0, 1.0) AS rank "
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

  /// Drops a dictionary's tables and meta row entirely.
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

import "dart:async";
import "dart:io";

import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/full_text_index_builder.dart";
import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search.dart";
import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

enum FullTextIndexStatus { notBuilt, building, ready, failed }

class FullTextIndexState {
  final FullTextIndexStatus status;
  final int indexed;
  final int total;

  const FullTextIndexState({
    required this.status,
    this.indexed = 0,
    this.total = 0,
  });

  double get progress => total <= 0 ? 0 : indexed / total;
}

typedef FullTextBuildRunner = Future<void> Function(
  FullTextBuildRequest request, {
  required Future<void> Function(List<FullTextIndexRow>, int, int) onBatch,
  required Future<void> Function(int) onTotal,
  required FullTextBuildCancelToken cancelToken,
});

/// Coordinates per-dictionary FTS5 indexes: lazy background builds with
/// resume, fingerprint invalidation, search across the active dictionaries,
/// and cleanup when a dictionary is removed.
///
/// The store lives in the cache directory next to the `.cidx` files: it is
/// rebuildable data, so a cache clear simply triggers a rebuild.
class FullTextSearchService extends ChangeNotifier {
  final List<DictionarySource> Function() dictionaries;

  /// Where the store file lives; override in tests with a temp directory.
  final Future<String> Function() _databaseDirectory;

  final FullTextBuildRunner _buildRunner;

  /// Dictionary ids whose index state is known from [dictionaryListDao].
  /// Used once to drop indexes orphaned by a removal.
  final Future<Set<int>> Function() _knownDictionaryIds;

  FullTextIndexStore? _store;
  Future<FullTextIndexStore>? _storeFuture;
  bool _reconciled = false;

  final Map<int, FullTextIndexState> _states = {};
  final Map<int, FullTextBuildCancelToken> _cancelTokens = {};
  final Map<int, Future<void>> _builds = {};

  FullTextSearchService({
    required this.dictionaries,
    required Future<Set<int>> Function() knownIds,
    Future<String> Function()? databaseDirectory,
    FullTextBuildRunner runner = runFullTextIndexBuild,
  }) : _knownDictionaryIds = knownIds,
       _databaseDirectory =
           databaseDirectory ??
           (() async => (await getApplicationCacheDirectory()).path),
       _buildRunner = runner;

  Map<int, FullTextIndexState> get states => Map.unmodifiable(_states);

  FullTextIndexState stateFor(int dictionaryId) =>
      _states[dictionaryId] ??
      const FullTextIndexState(status: FullTextIndexStatus.notBuilt);

  Future<FullTextIndexStore> _storeInstance() async {
    final pending = _storeFuture ??= _openStore();
    try {
      return await pending;
    } catch (_) {
      // Don't cache a failed open: the next call retries instead of
      // rethrowing the same failure forever.
      if (identical(_storeFuture, pending)) _storeFuture = null;
      rethrow;
    }
  }

  Future<FullTextIndexStore> _openStore() async {
    final dir = await _databaseDirectory();
    _store = await FullTextIndexStore.openFile(
      File(p.join(dir, "full_text_search.db")),
    );
    return _store!;
  }

  Future<void> _reconcileOnce() async {
    if (_reconciled) return;
    try {
      final store = await _storeInstance();
      await store.pruneExcept(await _knownDictionaryIds());
      final byId = <int, LoadedDictionary>{
        for (final d in dictionaries().whereType<LoadedDictionary>()) d.id: d,
      };
      for (final entry in await store.allMeta()) {
        var status = switch (entry.state) {
          FullTextIndexDbState.ready => FullTextIndexStatus.ready,
          FullTextIndexDbState.failed => FullTextIndexStatus.failed,
          FullTextIndexDbState.building => FullTextIndexStatus.notBuilt,
        };
        if (status == FullTextIndexStatus.ready) {
          // A meta row stamped ready is only trusted while its
          // fingerprint still matches the dictionary on disk. An index
          // built by an older schema (v1 has no `headword_rev`) or for
          // a replaced dictionary file would otherwise keep reporting
          // ready while every FTS query against it throws — which
          // `_searchReady` swallows per dictionary as silent empty
          // results. The downgrade is in-memory only; the rebuild
          // itself runs through `ensureBuilt`. A fingerprint that
          // cannot be computed (dictionary file gone, e.g. an
          // unmounted SD card) leaves the index alone: the file is
          // needed to rebuild anyway, so the stale tables stay usable
          // until it comes back. Dictionaries outside the current
          // group cannot be checked here — they have no type/path in
          // scope — the auto-build entries cover them when the group
          // becomes current.
          final dictionary = byId[entry.dictionaryId];
          if (dictionary != null) {
            try {
              final fingerprint = await fingerprintFor(
                dictionary.type,
                dictionary.path,
              );
              if (fingerprint.isNotEmpty && fingerprint != entry.fingerprint) {
                status = FullTextIndexStatus.notBuilt;
              }
            } catch (_) {
              // A stat failure must not break startup reconcile; the
              // next `ensureBuilt` re-checks the fingerprint.
            }
          }
        }
        _states[entry.dictionaryId] = FullTextIndexState(
          status: status,
          indexed: entry.indexed,
          total: entry.total,
        );
      }
      _reconciled = true;
      notifyListeners();
    } catch (_) {
      // A corrupt cache store must not break startup; the next build
      // recreates what it needs, and reconcile retries next time.
    }
  }

  /// The primary file whose size + mtime identifies a dictionary's content.
  /// Mirrors the `.cidx` fingerprint idea: a changed file rebuilds.
  ///
  /// The FTS schema version is stamped in front: when the table shape
  /// changes (v2 adds `headword_rev`), the fingerprint differs from the
  /// one stored with the old tables, so the index rebuilds instead of
  /// serving stale tables that the new queries cannot use.
  static Future<String> fingerprintFor(int type, String basePath) async {
    final candidates = <String>[];
    if (DictionaryType.isStardict(type)) {
      candidates.addAll([
        "$basePath.idx",
        "$basePath.idx.gz",
        "$basePath.idx.dz",
      ]);
    } else if (DictionaryType.isZim(type)) {
      candidates.add("$basePath.zim");
    } else {
      candidates.add("$basePath.mdx");
    }
    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) {
        final stat = await file.stat();
        return "v$fullTextIndexSchemaVersion:"
            "${stat.size}:${stat.modified.millisecondsSinceEpoch}";
      }
    }
    return "";
  }

  /// Makes sure [dictionary]'s index exists and is current, building it in
  /// the background when needed. Concurrent callers share one build.
  Future<void> ensureBuilt(LoadedDictionary dictionary) {
    final existing = _builds[dictionary.id];
    if (existing != null) return existing;
    final build = _ensureBuilt(dictionary);
    _builds[dictionary.id] = build;
    build.whenComplete(() => _builds.remove(dictionary.id));
    return build;
  }

  Future<void> _ensureBuilt(LoadedDictionary dictionary) async {
    await _reconcileOnce();
    final FullTextIndexStore store;
    final bool rebuild;
    try {
      store = await _storeInstance();
      final fingerprint = await fingerprintFor(
        dictionary.type,
        dictionary.path,
      );
      if (fingerprint.isEmpty) {
        // The dictionary file is not on disk (e.g. an unmounted SD
        // card): nothing can be built, and `ensureDictionary` would
        // drop the existing tables for a rebuild that cannot run. Leave
        // the state alone — a ready index stays usable, an unbuilt one
        // keeps its build button for when the file comes back.
        return;
      }
      rebuild = await store.ensureDictionary(dictionary.id, fingerprint);
    } catch (_) {
      // No usable store to record the failure in; keep it in memory so
      // the page can offer a retry instead of surfacing an unhandled
      // error from the unawaited build call.
      _states[dictionary.id] = const FullTextIndexState(
        status: FullTextIndexStatus.failed,
      );
      notifyListeners();
      return;
    }
    if (!rebuild) {
      final meta = await store.meta(dictionary.id);
      _states[dictionary.id] = FullTextIndexState(
        status: FullTextIndexStatus.ready,
        indexed: meta?.indexed ?? 0,
        total: meta?.total ?? 0,
      );
      notifyListeners();
      return;
    }
    final resumeFrom = (await store.meta(dictionary.id))?.indexed ?? 0;
    final cancelToken = FullTextBuildCancelToken();
    _cancelTokens[dictionary.id] = cancelToken;
    _states[dictionary.id] = FullTextIndexState(
      status: FullTextIndexStatus.building,
      indexed: resumeFrom,
    );
    notifyListeners();
    try {
      await _buildRunner(
        FullTextBuildRequest(
          dictionaryId: dictionary.id,
          type: dictionary.type,
          basePath: dictionary.path,
          startOrdinal: resumeFrom,
        ),
        onBatch: (rows, indexed, total) async {
          // Batches arrive in order; each write is awaited before the next
          // batch is consumed so progress never runs ahead of storage.
          await store.insertBatch(dictionary.id, rows, indexed);
          _states[dictionary.id] = FullTextIndexState(
            status: FullTextIndexStatus.building,
            indexed: indexed,
            total: total,
          );
          notifyListeners();
        },
        onTotal: (total) async {
          await store.setTotal(dictionary.id, total);
          final current = _states[dictionary.id];
          _states[dictionary.id] = FullTextIndexState(
            status: FullTextIndexStatus.building,
            indexed: current?.indexed ?? 0,
            total: total,
          );
          notifyListeners();
        },
        cancelToken: cancelToken,
      );
      if (cancelToken.isCancelled) {
        // Keep the partial index: the next build resumes from it.
        final meta = await store.meta(dictionary.id);
        _states[dictionary.id] = FullTextIndexState(
          status: FullTextIndexStatus.notBuilt,
          indexed: meta?.indexed ?? 0,
          total: meta?.total ?? 0,
        );
      } else {
        final meta = await store.meta(dictionary.id);
        await store.markComplete(dictionary.id, meta?.total ?? 0);
        _states[dictionary.id] = FullTextIndexState(
          status: FullTextIndexStatus.ready,
          indexed: meta?.indexed ?? 0,
          total: meta?.total ?? 0,
        );
      }
    } catch (_) {
      // markFailed itself may fail when the store is broken; the
      // in-memory state is what the page reads, so never let this throw.
      try {
        await store.markFailed(dictionary.id);
      } catch (_) {}
      _states[dictionary.id] = const FullTextIndexState(
        status: FullTextIndexStatus.failed,
      );
    } finally {
      _cancelTokens.remove(dictionary.id);
      notifyListeners();
    }
  }

  void cancelBuild(int dictionaryId) {
    _cancelTokens[dictionaryId]?.cancel();
  }

  /// Worst index status across the active dictionaries: a build in flight
  /// anywhere reports building, then a failed build, then a dictionary
  /// never built; only when every index is ready does this report ready.
  /// The search bar shows this instead of an unexplained empty list when a
  /// mode needs the index.
  Future<FullTextIndexStatus> indexStatus() async {
    await _reconcileOnce();
    var status = FullTextIndexStatus.ready;
    for (final dictionary in dictionaries()) {
      switch (stateFor(dictionary.id).status) {
        case FullTextIndexStatus.building:
          return FullTextIndexStatus.building;
        case FullTextIndexStatus.failed:
          status = FullTextIndexStatus.failed;
        case FullTextIndexStatus.notBuilt:
          if (status == FullTextIndexStatus.ready) {
            status = FullTextIndexStatus.notBuilt;
          }
        case FullTextIndexStatus.ready:
          break;
      }
    }
    return status;
  }

  /// Searches every active dictionary with a ready index. Dictionaries
  /// still building or never built are skipped; the page drives builds.
  Future<List<FullTextHit>> search(String query) async {
    final expression = buildFtsMatchExpression(query);
    if (expression.isEmpty) return const [];
    return _searchReady(
      (store, dictionaryId) =>
          store.searchOne(dictionaryId, expression, limit: 50),
    );
  }

  /// Suffix search across the active dictionaries: headwords ending with
  /// [query]. Same ready-only rule as [search].
  Future<List<FullTextHit>> searchSuffix(String query) async {
    if (buildSuffixMatchExpression(query).isEmpty) return const [];
    return _searchReady(
      (store, dictionaryId) =>
          store.searchSuffixOne(dictionaryId, query, limit: 50),
    );
  }

  /// Multi-word AND search across the active dictionaries: headwords
  /// containing every character/word of [query]. Same ready-only rule as
  /// [search].
  Future<List<FullTextHit>> searchHeadwordAnd(String query) async {
    if (buildHeadwordAndMatchExpression(query).isEmpty) return const [];
    return _searchReady(
      (store, dictionaryId) =>
          store.searchHeadwordAndOne(dictionaryId, query, limit: 50),
    );
  }

  /// Whether [error] shows the index tables do not match the query
  /// (stale or damaged tables), as opposed to a transient failure or a
  /// bad query. User input only ever reaches MATCH expressions, never a
  /// column or table position, so these SQLite messages can only come
  /// from our SQL against the wrong tables.
  bool _isIndexShapeError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains("no such column") ||
        message.contains("no such table") ||
        message.contains("column index out of range");
  }

  /// Runs [run] against every active dictionary with a ready index and
  /// merges the hits, best rank first, capped at 100. A dictionary still
  /// building, never built, or unreadable contributes nothing.
  Future<List<FullTextHit>> _searchReady(
    Future<List<FullTextHit>> Function(
      FullTextIndexStore store,
      int dictionaryId,
    )
    run,
  ) async {
    await _reconcileOnce();
    final FullTextIndexStore store;
    try {
      store = await _storeInstance();
    } catch (_) {
      // An unreadable cache store means no results, not a crash.
      return const [];
    }
    final hits = <FullTextHit>[];
    for (final dictionary in dictionaries()) {
      if (stateFor(dictionary.id).status != FullTextIndexStatus.ready) {
        continue;
      }
      try {
        hits.addAll(await run(store, dictionary.id));
      } catch (e) {
        // One unreadable index must not break search across the rest.
        // But a query that fails because the tables do not match the
        // query — a stale index whose shape predates the columns the
        // query needs — is index corruption, not a bad query: user
        // input only ever reaches MATCH expressions, never a column or
        // table position, so "no such column/table" and "column index
        // out of range" can only come from our SQL against the wrong
        // tables. Mark it failed so the full-text page offers a retry
        // instead of silently returning nothing. Anything else (a
        // locked database, an I/O error) leaves the state alone and
        // retries on the next search.
        if (_isIndexShapeError(e)) {
          _states[dictionary.id] = const FullTextIndexState(
            status: FullTextIndexStatus.failed,
          );
          try {
            await store.markFailed(dictionary.id);
          } catch (_) {}
          notifyListeners();
        }
      }
    }
    // bm25 ranks are per-table estimates, so cross-dictionary ordering is
    // approximate — good enough for a merged list.
    hits.sort((a, b) => a.rank.compareTo(b.rank));
    return hits.take(100).toList(growable: false);
  }

  /// Drops a dictionary's index entirely, e.g. when it is removed.
  Future<void> dropDictionary(int dictionaryId) async {
    final store = await _storeInstance();
    await store.dropDictionary(dictionaryId);
    _states.remove(dictionaryId);
    notifyListeners();
  }

  /// On-disk size of one dictionary's index in bytes, 0 when it has none.
  /// Never throws: the settings UI reads it on page open.
  Future<int> indexSizeBytes(int dictionaryId) async {
    try {
      final store = await _storeInstance();
      return await store.indexSizeBytes(dictionaryId);
    } catch (_) {
      return 0;
    }
  }

  /// Deletes a dictionary's index and builds it again from scratch. A
  /// build already in flight is cancelled first and awaited, so its late
  /// batches cannot land in the fresh tables.
  Future<void> rebuildDictionary(LoadedDictionary dictionary) async {
    cancelBuild(dictionary.id);
    await _builds[dictionary.id];
    await dropDictionary(dictionary.id);
    await ensureBuilt(dictionary);
  }

  @override
  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    unawaited(_store?.close());
    super.dispose();
  }
}

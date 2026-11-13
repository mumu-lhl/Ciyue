import "dart:async";
import "dart:isolate";

import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search.dart";
import "package:dict_reader/dict_reader.dart";

/// Maximum plain-text characters indexed per entry. Encyclopedia entries can
/// be megabytes; beyond this the snippet value is nil and the index bloats.
const int _maxBodyChars = 100000;

/// What the builder isolate needs: everything must be sendable, so the
/// isolate opens its own reader from [basePath] (the same rule as the ZIM
/// isolate fix: pass path strings, never reader objects).
class FullTextBuildRequest {
  final int dictionaryId;
  final int type;
  final String basePath;

  /// Rows already stored from an earlier (cancelled) run; iteration skips
  /// this many emitted rows so a build resumes instead of restarting.
  final int startOrdinal;
  final int batchSize;

  const FullTextBuildRequest({
    required this.dictionaryId,
    required this.type,
    required this.basePath,
    this.startOrdinal = 0,
    this.batchSize = 500,
  });

  Map<String, Object?> toMessage() => {
    "dictionaryId": dictionaryId,
    "type": type,
    "basePath": basePath,
    "startOrdinal": startOrdinal,
    "batchSize": batchSize,
  };

  static FullTextBuildRequest fromMessage(Map<String, Object?> message) {
    return FullTextBuildRequest(
      dictionaryId: message["dictionaryId"] as int,
      type: message["type"] as int,
      basePath: message["basePath"] as String,
      startOrdinal: message["startOrdinal"] as int? ?? 0,
      batchSize: message["batchSize"] as int? ?? 500,
    );
  }
}

/// Cooperative cancellation for a running build.
class FullTextBuildCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class _Emitter {
  final SendPort _port;
  final int _startOrdinal;
  final int _batchSize;
  final bool Function() _isCancelled;

  /// Called after a batch is sent; resolves when the main isolate has
  /// written it (see [runFullTextIndexBuild]). The builder parks here
  /// instead of queueing batches ahead of the writer: backpressure (P1-8)
  /// is one batch in flight, so a slow disk cannot pile up unread bodies
  /// in memory.
  final Future<void> Function() _waitForAck;

  /// Entries considered so far, including skipped ones; also the row id of
  /// the next emitted row, which keeps row ids stable across resumes.
  int seen = 0;
  int total = 0;
  final List<List<Object>> _batch = [];

  _Emitter(
    this._port,
    this._startOrdinal,
    this._batchSize,
    this._isCancelled,
    this._waitForAck,
  );

  bool get cancelled => _isCancelled();

  /// Advances past one candidate row. Returns false when the caller must
  /// skip the expensive read/strip for this row: either it has no headword
  /// (never counted, never emitted) or it was already stored by an earlier
  /// run ([seen] still advances, so the resume point keeps counting the
  /// rows it skips — this is what makes a resumed build fast-forward
  /// instead of re-reading and re-stripping everything it already has).
  ///
  /// Callers check this BEFORE doing a dictionary lookup or stripping any
  /// body (P1-5). A row whose stripped body turns out empty is counted
  /// here but never emitted (see [addBody]); its row id stays unused,
  /// which a resumed build reproduces because it counts the same way.
  bool needsBody(String headword) {
    if (headword.isEmpty) return false;
    seen++;
    return seen > _startOrdinal;
  }

  /// Strips, cuts and tokenizes [rawBody] and queues the row. Call only
  /// after [needsBody] returned true. The raw body is passed in so the
  /// strip — and, for resumed builds, the whole body read — can be skipped.
  ///
  /// Tokenization happens here, in the builder isolate: a batch leaves
  /// with all three tokenized columns attached, so the main isolate only
  /// issues the write and never runs [tokenizeForIndex] over megabytes of
  /// body text (P0-6).
  Future<void> addBody(String headword, String rawBody) async {
    var body = stripHtmlToText(rawBody);
    if (body.isEmpty) return;
    if (body.length > _maxBodyChars) {
      // Cut on a rune boundary: splitting a surrogate pair would store a
      // lone surrogate, which the SQLite binding cannot encode.
      body = String.fromCharCodes(body.runes.take(_maxBodyChars));
    }
    final headwordRev = reverseHeadword(headword);
    _batch.add([
      seen,
      headword,
      headwordRev,
      body,
      tokenizeForIndex(headword),
      tokenizeForIndex(headwordRev),
      tokenizeForIndex(body),
    ]);
    if (_batch.length >= _batchSize) {
      await flush();
    }
  }

  /// Sends the buffered batch and waits for the main isolate's ack before
  /// the builder reads on. See [_waitForAck].
  Future<void> flush() async {
    if (_batch.isEmpty) return;
    _port.send({
      "kind": "batch",
      "rows": List<List<Object>>.of(_batch),
      "indexed": seen,
      "total": total,
    });
    _batch.clear();
    await _waitForAck();
  }
}

Future<void> _buildMdx(String basePath, _Emitter emitter, SendPort port) async {
  final reader = DictReader("$basePath.mdx");
  try {
    await reader.initDict();
    emitter.total = reader.numEntries;
    port.send({"kind": "total", "total": emitter.total});
    await for (final record in reader.readWithMdxData()) {
      if (emitter.cancelled) break;
      try {
        // The resume check runs before the strip: a skipped row pays
        // neither the strip nor the tokenization (P1-5).
        if (!emitter.needsBody(record.keyText)) continue;
        await emitter.addBody(record.keyText, record.data);
      } catch (_) {
        // One unreadable record must not kill the whole build.
      }
    }
  } finally {
    await reader.close();
  }
}

Future<void> _buildStardict(
  String basePath,
  _Emitter emitter,
  SendPort port,
) async {
  final reader = StarDictReader(basePath);
  try {
    await reader.init();
    emitter.total = reader.wordCount;
    port.send({"kind": "total", "total": emitter.total});
    for (var i = 0; i < reader.wordCount; i++) {
      if (emitter.cancelled) break;
      final word = reader.wordAt(i);
      // The resume check runs before the lookup: a skipped row pays no
      // disk read at all (P1-5).
      if (!emitter.needsBody(word)) continue;
      try {
        final entries = await reader.lookup(word);
        if (entries.isEmpty) continue;
        final body = entries
            .expand((entry) => entry.fields)
            .where((field) => field.isText)
            .map((field) => field.text!)
            .join("\n");
        await emitter.addBody(word, body);
      } catch (_) {
        // One unreadable entry must not kill the whole build.
      }
    }
  } finally {
    await reader.close();
  }
}

Future<void> _buildZim(String basePath, _Emitter emitter, SendPort port) async {
  final reader = ZimReader("$basePath.zim");
  try {
    // Already off the UI thread: parse the index inline instead of nesting
    // another isolate inside this one.
    await reader.init(useIsolate: false);
    emitter.total = reader.wordCount;
    port.send({"kind": "total", "total": emitter.total});
    // Titles arrive in dirent order with duplicates; sorting their indices
    // once makes duplicates adjacent so they can be marked with a single
    // pass instead of a Set<String> holding every title seen (about
    // 50–100B per entry in the set's hash table — at wiki scale hundreds
    // of MB; the index list costs one int per title, plus one bool per
    // title for the marks). A Set<int> of loop positions cannot do this:
    // positions are unique, titles are not.
    //
    // Iteration stays in dirent order, exactly as before this change:
    // row ids are assigned in that order, so a build started by the
    // previous release resumes at the same row. (Sorting the iteration
    // itself would remap row ids and silently skip entries a resumed
    // build assumes are already stored.)
    final order = List<int>.generate(reader.wordCount, (i) => i)
      ..sort((a, b) => reader.wordAt(a).compareTo(reader.wordAt(b)));
    // The sort is stable, so the first of a run of equal titles is the
    // earliest dirent occurrence — the same one the old Set<String> kept.
    final isDuplicate = List<bool>.filled(reader.wordCount, false);
    for (var k = 1; k < order.length; k++) {
      if (reader.wordAt(order[k]) == reader.wordAt(order[k - 1])) {
        isDuplicate[order[k]] = true;
      }
    }
    for (var i = 0; i < reader.wordCount; i++) {
      if (emitter.cancelled) break;
      if (isDuplicate[i]) continue;
      final title = reader.wordAt(i);
      // The resume check runs before the lookup: a skipped row pays no
      // disk read at all (P1-5).
      if (!emitter.needsBody(title)) continue;
      try {
        final entries = await reader.lookup(title);
        if (entries.isEmpty) continue;
        final entry = entries.firstWhere(
          (candidate) => candidate.title == title,
          orElse: () => entries.first,
        );
        await emitter.addBody(title, await entry.readText());
      } catch (_) {
        // One unreadable article must not kill the whole build.
      }
    }
  } finally {
    await reader.close();
  }
}

/// Entry point for the index-builder isolate. Must stay a top-level
/// function; it only receives sendable values.
Future<void> fullTextIndexBuilderEntry(List<Object?> args) async {
  final mainPort = args[0] as SendPort;
  final request = FullTextBuildRequest.fromMessage(
    args[1] as Map<String, Object?>,
  );
  final commandPort = ReceivePort();
  mainPort.send({"kind": "ready", "port": commandPort.sendPort});
  var cancelled = false;
  // The ack for the batch currently in flight, if any. Completed by the
  // main isolate after it writes the batch ("ack"), or by a "cancel" so a
  // batch parked on its ack cannot deadlock the build.
  Completer<void>? pendingAck;

  // An "ack" and a "cancel" can both arrive for the same batch (the main
  // isolate acks a batch it just wrote, then notices the token was
  // cancelled during the write): completing the same completer twice
  // throws, so guard it.
  void completePendingAck() {
    final ack = pendingAck;
    if (ack != null && !ack.isCompleted) ack.complete();
  }

  commandPort.listen((message) {
    if (message == "cancel") {
      cancelled = true;
      completePendingAck();
    } else if (message is Map<String, Object?> && message["kind"] == "ack") {
      completePendingAck();
    }
  });
  try {
    final emitter = _Emitter(
      mainPort,
      request.startOrdinal,
      request.batchSize,
      () => cancelled,
      () {
        pendingAck = Completer<void>();
        return pendingAck!.future;
      },
    );
    if (DictionaryType.isStardict(request.type)) {
      await _buildStardict(request.basePath, emitter, mainPort);
    } else if (DictionaryType.isZim(request.type)) {
      await _buildZim(request.basePath, emitter, mainPort);
    } else {
      await _buildMdx(request.basePath, emitter, mainPort);
    }
    await emitter.flush();
    mainPort.send({
      "kind": cancelled ? "cancelled" : "done",
      "indexed": emitter.seen,
      "total": emitter.total,
    });
  } catch (e) {
    mainPort.send({"kind": "error", "message": "$e"});
  } finally {
    commandPort.close();
  }
}

/// Runs one build in a background isolate, streaming batches to [onBatch].
/// Each batch is awaited before the next is consumed, so writes stay in
/// order — and the isolate itself waits for an ack after sending each
/// batch, so at most one batch is in flight (backpressure, P1-8). Throws
/// when the isolate reports an error or exits unfinished.
Future<void> runFullTextIndexBuild(
  FullTextBuildRequest request, {
  required Future<void> Function(
    List<FullTextIndexRow> rows,
    int indexed,
    int total,
  )
  onBatch,
  required Future<void> Function(int total) onTotal,
  required FullTextBuildCancelToken cancelToken,
}) async {
  final mainPort = ReceivePort();
  final isolate = await Isolate.spawn(fullTextIndexBuilderEntry, [
    mainPort.sendPort,
    request.toMessage(),
  ]);
  SendPort? commandPort;
  var finished = false;
  try {
    await for (final message in mainPort) {
      final map = message as Map<String, Object?>;
      switch (map["kind"]) {
        case "ready":
          commandPort = map["port"] as SendPort;
          break;
        case "total":
          await onTotal(map["total"] as int);
          break;
        case "batch":
          // Batches already queued when cancellation lands are dropped
          // instead of delivered: the isolate may have sent them before
          // it saw the cancel message, and storing them would overrun the
          // resume point the caller recorded.
          if (cancelToken.isCancelled) break;
          final rows = [
            for (final raw in map["rows"] as List)
              FullTextIndexRow(
                rowid: (raw as List)[0] as int,
                headword: raw[1] as String,
                headwordRev: raw[2] as String,
                body: raw[3] as String,
                headwordTokenized: raw[4] as String,
                headwordRevTokenized: raw[5] as String,
                bodyTokenized: raw[6] as String,
              ),
          ];
          await onBatch(rows, map["indexed"] as int, map["total"] as int);
          // The ack releases the builder isolate to read the next batch.
          // Sent only for batches that were actually written; a dropped
          // batch is answered by the "cancel" below instead, so the
          // isolate cannot park on an ack that never comes.
          commandPort?.send({"kind": "ack"});
          break;
        case "done":
        case "cancelled":
          finished = true;
          return;
        case "error":
          throw StateError(map["message"] as String? ?? "index build failed");
      }
      if (cancelToken.isCancelled) {
        commandPort?.send("cancel");
      }
    }
  } finally {
    mainPort.close();
    isolate.kill(priority: Isolate.immediate);
  }
  if (!finished) {
    throw StateError("index builder exited without finishing");
  }
}

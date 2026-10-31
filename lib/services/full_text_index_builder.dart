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

  /// Entries considered so far, including skipped ones; also the row id of
  /// the next emitted row, which keeps row ids stable across resumes.
  int seen = 0;
  int total = 0;
  final List<List<Object>> _batch = [];

  _Emitter(this._port, this._startOrdinal, this._batchSize, this._isCancelled);

  bool get cancelled => _isCancelled();

  void add(String headword, String body) {
    if (headword.isEmpty || body.isEmpty) return;
    seen++;
    if (seen <= _startOrdinal) return;
    if (body.length > _maxBodyChars) {
      // Cut on a rune boundary: splitting a surrogate pair would store a
      // lone surrogate, which the SQLite binding cannot encode.
      body = String.fromCharCodes(body.runes.take(_maxBodyChars));
    }
    _batch.add([seen, headword, body]);
    if (_batch.length >= _batchSize) {
      flush();
    }
  }

  void flush() {
    if (_batch.isEmpty) return;
    _port.send({
      "kind": "batch",
      "rows": List<List<Object>>.of(_batch),
      "indexed": seen,
      "total": total,
    });
    _batch.clear();
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
        emitter.add(record.keyText, stripHtmlToText(record.data));
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
      try {
        final entries = await reader.lookup(word);
        if (entries.isEmpty) continue;
        final body = entries
            .expand((entry) => entry.fields)
            .where((field) => field.isText)
            .map((field) => field.text!)
            .join("\n");
        emitter.add(word, stripHtmlToText(body));
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
    final seenTitles = <String>{};
    for (var i = 0; i < reader.wordCount; i++) {
      if (emitter.cancelled) break;
      final title = reader.wordAt(i);
      if (!seenTitles.add(title)) continue;
      try {
        final entries = await reader.lookup(title);
        if (entries.isEmpty) continue;
        final entry = entries.firstWhere(
          (candidate) => candidate.title == title,
          orElse: () => entries.first,
        );
        emitter.add(title, stripHtmlToText(await entry.readText()));
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
  commandPort.listen((message) {
    if (message == "cancel") cancelled = true;
  });
  try {
    final emitter = _Emitter(
      mainPort,
      request.startOrdinal,
      request.batchSize,
      () => cancelled,
    );
    if (DictionaryType.isStardict(request.type)) {
      await _buildStardict(request.basePath, emitter, mainPort);
    } else if (DictionaryType.isZim(request.type)) {
      await _buildZim(request.basePath, emitter, mainPort);
    } else {
      await _buildMdx(request.basePath, emitter, mainPort);
    }
    emitter.flush();
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
/// order. Throws when the isolate reports an error or exits unfinished.
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
                body: raw[2] as String,
              ),
          ];
          await onBatch(rows, map["indexed"] as int, map["total"] as int);
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

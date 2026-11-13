import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:isolate";
import "dart:typed_data";

import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/full_text_index_builder.dart";
import "package:ciyue/services/full_text_index_store.dart";
import "package:flutter_test/flutter_test.dart";

import "../zim_fixture.dart";

// Builds a minimal uncompressed UTF-8 .mdx: one key block, one record
// block, no encryption. Mirrors dict_reader's own test fixture.
Future<File> writeMdxFixture(
  Directory dir,
  List<(String, String)> entries,
) async {
  void writeUint32BE(BytesBuilder builder, int value) {
    builder.add(
      (ByteData(4)..setUint32(0, value, Endian.big)).buffer.asUint8List(),
    );
  }

  void writeUint32LE(BytesBuilder builder, int value) {
    builder.add(
      (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List(),
    );
  }

  List<int> block(List<int> payload) {
    final builder = BytesBuilder();
    writeUint32LE(builder, 0);
    writeUint32BE(builder, 0);
    builder.add(payload);
    return builder.toBytes();
  }

  final keyBytes = entries.map((e) => utf8.encode(e.$1)).toList();
  final values = entries.map((e) => utf8.encode(e.$2)).toList();
  final keyPayload = BytesBuilder();
  var recordOffset = 0;
  for (var i = 0; i < keyBytes.length; i++) {
    writeUint32BE(keyPayload, recordOffset);
    keyPayload.add(keyBytes[i]);
    keyPayload.addByte(0);
    recordOffset += values[i].length;
  }
  final keyBlock = block(keyPayload.toBytes());
  final keyInfo = BytesBuilder();
  writeUint32BE(keyInfo, entries.length);
  keyInfo.add([0, 0]);
  writeUint32BE(keyInfo, keyBlock.length);
  writeUint32BE(keyInfo, keyBlock.length - 8);

  final recordPayload = values.expand((value) => value).toList();
  final recordBlock = block(recordPayload);

  final header = utf8.encode(
    '<Dictionary><Encoding="UTF-8" GeneratedByEngineVersion="1.0" '
    'Encrypted="No"/></Dictionary>\u0000',
  );
  final file = BytesBuilder();
  writeUint32BE(file, header.length);
  file.add(header);
  writeUint32LE(file, 0);
  writeUint32BE(file, 1);
  writeUint32BE(file, entries.length);
  writeUint32BE(file, keyInfo.length);
  writeUint32BE(file, keyBlock.length);
  file.add(keyInfo.toBytes());
  file.add(keyBlock);
  writeUint32BE(file, 1);
  writeUint32BE(file, entries.length);
  writeUint32BE(file, 8);
  writeUint32BE(file, recordBlock.length);
  writeUint32BE(file, recordBlock.length);
  writeUint32BE(file, recordBlock.length - 8);
  file.add(recordBlock);
  final result = File("${dir.path}/fixture.mdx");
  return result.writeAsBytes(file.toBytes());
}

// Minimal StarDict writer: plain-text 'm' fields, no sametypesequence.
Future<String> writeStardictFixture(
  Directory dir,
  List<(String, String)> entries,
) async {
  final dictBytes = BytesBuilder();
  final locations = <(int, int)>[];
  for (final (_, definition) in entries) {
    final encoded = BytesBuilder()
      ..addByte("m".codeUnitAt(0))
      ..add(utf8.encode(definition))
      ..addByte(0);
    final bytes = encoded.takeBytes();
    locations.add((dictBytes.length, bytes.length));
    dictBytes.add(bytes);
  }
  final dictData = dictBytes.takeBytes();
  final idx = BytesBuilder();
  for (var i = 0; i < entries.length; i++) {
    idx.add(utf8.encode(entries[i].$1));
    idx.addByte(0);
    final (offset, size) = locations[i];
    idx.add(
      (ByteData(4)..setUint32(0, offset, Endian.big)).buffer.asUint8List(),
    );
    idx.add((ByteData(4)..setUint32(0, size, Endian.big)).buffer.asUint8List());
  }
  final idxData = idx.takeBytes();
  final base = "${dir.path}/basic";
  await File("$base.idx").writeAsBytes(idxData);
  await File("$base.dict").writeAsBytes(dictData);
  await File("$base.ifo").writeAsString(
    "StarDict's dict ifo file\n"
    "version=2.4.2\n"
    "bookname=Test Dictionary\n"
    "wordcount=${entries.length}\n"
    "idxfilesize=${idxData.length}\n",
  );
  return base;
}

Future<List<FullTextIndexRow>> collectBuild(
  FullTextBuildRequest request, {
  FullTextBuildCancelToken? cancelToken,
  void Function(int indexed, int total)? onFirstBatch,
}) async {
  final rows = <FullTextIndexRow>[];
  var firstBatch = true;
  await runFullTextIndexBuild(
    request,
    onBatch: (batch, indexed, total) async {
      rows.addAll(batch);
      if (firstBatch) {
        firstBatch = false;
        onFirstBatch?.call(indexed, total);
      }
    },
    onTotal: (_) async {},
    cancelToken: cancelToken ?? FullTextBuildCancelToken(),
  );
  return rows;
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp("fts_builder_test_");
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test("builds an MDX index through the isolate", () async {
    await writeMdxFixture(dir, const [
      ("apple", "<p>A <b>fruit</b> that grows on trees</p>"),
      ("banana", "<p>A yellow fruit</p>"),
    ]);
    final rows = await collectBuild(
      FullTextBuildRequest(
        dictionaryId: 1,
        type: 1,
        basePath: "${dir.path}/fixture",
        batchSize: 1,
      ),
    );
    expect(rows.map((r) => (r.rowid, r.headword, r.body)).toList(), [
      (1, "apple", "A fruit that grows on trees"),
      (2, "banana", "A yellow fruit"),
    ]);
  });

  test("oversized bodies are cut on a rune boundary", () async {
    final body = "${"a" * 99999}😀${"b" * 20}";
    await writeMdxFixture(dir, [("apple", body)]);
    final rows = await collectBuild(
      FullTextBuildRequest(
        dictionaryId: 1,
        type: 1,
        basePath: "${dir.path}/fixture",
      ),
    );
    expect(rows, hasLength(1));
    // 99999 a's + the emoji: exactly the cap, with no lone surrogate.
    expect(rows.single.body.runes.length, 100000);
    expect(rows.single.body.endsWith("😀"), isTrue);
  });

  test("builds a StarDict index through the isolate", () async {
    final base = await writeStardictFixture(dir, const [
      ("apple", "A round fruit"),
      ("苹果", "一种水果"),
    ]);
    final rows = await collectBuild(
      FullTextBuildRequest(
        dictionaryId: 2,
        type: DictionaryType.stardict,
        basePath: base,
      ),
    );
    expect(rows.map((r) => (r.headword, r.body)).toList(), [
      ("apple", "A round fruit"),
      ("苹果", "一种水果"),
    ]);
  });

  test("builds a ZIM index through the isolate", () async {
    final builder = ZimFixtureBuilder()
      ..addArticle("apple", "Apple", "<p>A fruit</p>")
      ..addArticle("banana", "Banana", "<p>A yellow fruit</p>");
    final zimPath = await builder.write(dir, "zimtest");
    final rows = await collectBuild(
      FullTextBuildRequest(
        dictionaryId: 3,
        type: DictionaryType.zim,
        basePath: zimPath.replaceAll(RegExp(r"\.zim$"), ""),
      ),
    );
    expect(rows.map((r) => (r.headword, r.body)).toList(), [
      ("Apple", "A fruit"),
      ("Banana", "A yellow fruit"),
    ]);
  });

  test("emitted rows carry pre-tokenized columns", () async {
    await writeMdxFixture(dir, const [
      ("apple", "<p>A <b>fruit</b> that grows on trees</p>"),
      ("苹果", "<p>一种水果</p>"),
    ]);
    final rows = await collectBuild(
      FullTextBuildRequest(
        dictionaryId: 1,
        type: 1,
        basePath: "${dir.path}/fixture",
      ),
    );
    expect(rows.map((r) => r.headword), ["apple", "苹果"]);
    // The builder isolate tokenizes, so the main isolate only writes.
    expect(rows[0].headwordRev, "elppa");
    expect(rows[0].headwordTokenized, "apple");
    expect(rows[0].headwordRevTokenized, "elppa");
    expect(rows[0].bodyTokenized, "A fruit that grows on trees");
    expect(rows[1].headwordRev, "果苹");
    expect(rows[1].headwordTokenized, "苹 果");
    expect(rows[1].headwordRevTokenized, "果 苹");
    expect(rows[1].bodyTokenized, "一 种 水 果");
  });

  test("resume reuses the same row ids, including rows with empty "
      "bodies", () async {
    // Rows whose stripped body is empty are counted but never emitted,
    // which leaves gaps in the row ids. A resumed build must reproduce
    // the same counting, or it would skip live rows or re-emit stored
    // ones under new row ids.
    await writeMdxFixture(dir, const [
      ("one", "first"),
      ("empty", ""),
      ("two", "second"),
      ("htmlonly", "<p></p>"),
      ("three", "third"),
    ]);
    final full = await collectBuild(
      FullTextBuildRequest(
        dictionaryId: 4,
        type: 1,
        basePath: "${dir.path}/fixture",
      ),
    );
    expect(full.map((r) => (r.rowid, r.headword)).toList(), [
      (1, "one"),
      (3, "two"),
      (5, "three"),
    ]);

    final resumed = await collectBuild(
      FullTextBuildRequest(
        dictionaryId: 4,
        type: 1,
        basePath: "${dir.path}/fixture",
        startOrdinal: 3,
      ),
    );
    expect(resumed.map((r) => (r.rowid, r.headword)).toList(), [(5, "three")]);
    expect(resumed.single.body, "third");
  });

  test("ZIM build emits each title once", () async {
    final builder = ZimFixtureBuilder()
      // Paths and titles order differently on purpose: the build must keep
      // the reader's order (row ids are assigned in it, so a build started
      // by the previous release resumes at the same row), not re-sort by
      // title — "Banana" (path "apple") comes before "Apple" (path
      // "apple2"), and the duplicate "Apple" (path "zebra") is skipped.
      ..addArticle("zebra", "Apple", "<p>A fruit</p>")
      ..addArticle("apple", "Banana", "<p>A yellow fruit</p>")
      ..addArticle("apple2", "Apple", "<p>A fruit</p>");
    final zimPath = await builder.write(dir, "zimtest");
    final rows = await collectBuild(
      FullTextBuildRequest(
        dictionaryId: 3,
        type: DictionaryType.zim,
        basePath: zimPath.replaceAll(RegExp(r"\.zim$"), ""),
      ),
    );
    // Reader order, not title-sorted order: Banana first, then Apple once.
    expect(rows.map((r) => (r.rowid, r.headword, r.body)).toList(), [
      (1, "Banana", "A yellow fruit"),
      (2, "Apple", "A fruit"),
    ]);
  });

  test(
    "builder waits for the batch ack before sending the next batch",
    () async {
      // Drives fullTextIndexBuilderEntry directly with a minimal main loop
      // that acks each batch after 100ms: with backpressure, batch N+1 only
      // arrives after the ack for batch N (~100ms later); without it, all
      // batches would arrive within a few milliseconds of each other. The
      // listener never awaits the ack delay, so an arrival timestamp is the
      // send time, not the consumption time.
      await writeMdxFixture(dir, const [
        ("one", "first"),
        ("two", "second"),
        ("three", "third"),
        ("four", "fourth"),
      ]);
      final mainPort = ReceivePort();
      final isolate = await Isolate.spawn(fullTextIndexBuilderEntry, [
        mainPort.sendPort,
        FullTextBuildRequest(
          dictionaryId: 9,
          type: 1,
          basePath: "${dir.path}/fixture",
          batchSize: 1,
        ).toMessage(),
      ]);
      final done = Completer<void>();
      final batchArrivals = <DateTime>[];
      SendPort? commandPort;
      try {
        final subscription = mainPort.listen((message) {
          final map = message as Map<String, Object?>;
          switch (map["kind"]) {
            case "ready":
              commandPort = map["port"] as SendPort;
            case "batch":
              batchArrivals.add(DateTime.now());
              // Fire-and-forget: the ack goes out 100ms after arrival.
              Future.delayed(const Duration(milliseconds: 100), () {
                commandPort?.send({"kind": "ack"});
              });
            case "done":
            case "cancelled":
              if (!done.isCompleted) done.complete();
            case "error":
              if (!done.isCompleted) {
                done.completeError(
                  StateError(map["message"] as String? ?? "build failed"),
                );
              }
          }
        });
        await done.future.timeout(const Duration(seconds: 10));
        await subscription.cancel();
        expect(batchArrivals, hasLength(4));
        for (var i = 1; i < batchArrivals.length; i++) {
          final gap = batchArrivals[i]
              .difference(batchArrivals[i - 1])
              .inMilliseconds;
          // ~100ms ack delay, minus scheduling slack.
          expect(gap, greaterThanOrEqualTo(60));
        }
      } finally {
        mainPort.close();
        isolate.kill(priority: Isolate.immediate);
      }
    },
  );

  test("cancel stops the build and resume continues it", () async {
    await writeMdxFixture(dir, const [
      ("one", "first"),
      ("two", "second"),
      ("three", "third"),
      ("four", "fourth"),
    ]);
    final token = FullTextBuildCancelToken();
    final partial = await collectBuild(
      FullTextBuildRequest(
        dictionaryId: 4,
        type: 1,
        basePath: "${dir.path}/fixture",
        batchSize: 2,
      ),
      cancelToken: token,
      onFirstBatch: (_, _) => token.cancel(),
    );
    // The first batch of 2 rows was delivered before cancellation.
    expect(partial.map((r) => r.headword), ["one", "two"]);

    final rest = await collectBuild(
      FullTextBuildRequest(
        dictionaryId: 4,
        type: 1,
        basePath: "${dir.path}/fixture",
        startOrdinal: partial.length,
        batchSize: 2,
      ),
    );
    expect(rest.map((r) => r.headword), ["three", "four"]);
    expect(rest.map((r) => r.rowid), [3, 4]);
  });
}

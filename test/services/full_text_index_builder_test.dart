import "dart:convert";
import "dart:io";
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

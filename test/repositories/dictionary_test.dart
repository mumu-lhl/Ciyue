import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart" hide expect, test;
import "package:test/test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel("plugins.flutter.io/path_provider"),
        (call) async => Directory.systemTemp.path,
      );

  test("follows chained @@@LINK records", () async {
    final directory = await Directory.systemTemp.createTemp("ciyue_mdict_");
    final mdxFile = await _writeMdx(directory, [
      ("book", "<p>book definition</p>"),
      ("books", "@@@LINK=plural"),
      ("plural", "@@@LINK=book"),
    ]);
    final path = mdxFile.path.substring(0, mdxFile.path.length - 4);
    await dictionaryListDao.add(path, "Test dictionary");
    final dictionary = Mdict(path: path);

    addTearDown(() async {
      await dictionary.close();
      await dictionaryListDao.remove(path);
      await directory.delete(recursive: true);
    });

    await dictionary.init();

    final entry = await dictionary.readExactEntry("books");

    expect(entry?.content, "<p>book definition</p>");
  });

  test("resolves links without dropping duplicate-key definitions", () async {
    final directory = await Directory.systemTemp.createTemp("ciyue_mdict_");
    final mdxFile = await _writeMdx(directory, [
      ("book", "<p>book definition</p>"),
      ("other", "<p>other definition</p>"),
      ("books", "@@@LINK=book"),
      ("books", "@@@LINK=other"),
      ("books", "<p>variant definition</p>"),
    ]);
    final path = mdxFile.path.substring(0, mdxFile.path.length - 4);
    await dictionaryListDao.add(path, "Test dictionary");
    final dictionary = Mdict(path: path);

    addTearDown(() async {
      await dictionary.close();
      await dictionaryListDao.remove(path);
      await directory.delete(recursive: true);
    });

    await dictionary.init();

    final entry = await dictionary.readExactEntry("books");

    expect(
      entry?.content,
      allOf(
        contains("<p>book definition</p>"),
        contains("<p>other definition</p>"),
        contains("<p>variant definition</p>"),
        isNot(contains("@@@LINK=")),
      ),
    );
  });

  test("resolves concatenated @@@LINK records with separators", () async {
    final directory = await Directory.systemTemp.createTemp("ciyue_mdict_");
    final mdxFile = await _writeMdx(directory, [
      ("first", "<p>first definition</p>"),
      ("second", "<p>second definition</p>"),
      ("third", "<p>third definition</p>"),
      ("fourth", "<p>fourth definition</p>"),
      (
        "alias",
        "@@@LINK=first\n@@@LINK=second\r@@@LINK=third\u0000@@@LINK=fourth",
      ),
    ]);
    final path = mdxFile.path.substring(0, mdxFile.path.length - 4);
    await dictionaryListDao.add(path, "Test dictionary");
    final dictionary = Mdict(path: path);

    addTearDown(() async {
      await dictionary.close();
      await dictionaryListDao.remove(path);
      await directory.delete(recursive: true);
    });

    await dictionary.init();

    final entry = await dictionary.readExactEntry("alias");

    expect(
      entry?.content,
      allOf(
        contains("<p>first definition</p>"),
        contains("<p>second definition</p>"),
        contains("<p>third definition</p>"),
        contains("<p>fourth definition</p>"),
        isNot(contains("@@@LINK=")),
      ),
    );
  });

  test("keeps unresolved links instead of fuzzy matching", () async {
    final directory = await Directory.systemTemp.createTemp("ciyue_mdict_");
    final mdxFile = await _writeMdx(directory, [
      ("alias", "@@@LINK=boook"),
      ("book", "<p>book definition</p>"),
    ]);
    final path = mdxFile.path.substring(0, mdxFile.path.length - 4);
    await dictionaryListDao.add(path, "Test dictionary");
    final dictionary = Mdict(path: path);

    addTearDown(() async {
      await dictionary.close();
      await dictionaryListDao.remove(path);
      await directory.delete(recursive: true);
    });

    await dictionary.init();

    final entry = await dictionary.readExactEntry("alias");

    expect(entry?.content, "@@@LINK=boook");
  });

  test("trims whitespace around @@@LINK targets", () async {
    final directory = await Directory.systemTemp.createTemp("ciyue_mdict_");
    final mdxFile = await _writeMdx(directory, [
      ("book", "<p>book definition</p>"),
      ("alias", " \n@@@LINK= book \r\n"),
    ]);
    final path = mdxFile.path.substring(0, mdxFile.path.length - 4);
    await dictionaryListDao.add(path, "Test dictionary");
    final dictionary = Mdict(path: path);

    addTearDown(() async {
      await dictionary.close();
      await dictionaryListDao.remove(path);
      await directory.delete(recursive: true);
    });

    await dictionary.init();

    final entry = await dictionary.readExactEntry("alias");

    expect(entry?.content, "<p>book definition</p>");
  });

  test("stops cyclic @@@LINK records", () async {
    final directory = await Directory.systemTemp.createTemp("ciyue_mdict_");
    final mdxFile = await _writeMdx(directory, [
      ("a", "@@@LINK=b"),
      ("b", "@@@LINK=a"),
    ]);
    final path = mdxFile.path.substring(0, mdxFile.path.length - 4);
    await dictionaryListDao.add(path, "Test dictionary");
    final dictionary = Mdict(path: path);

    addTearDown(() async {
      await dictionary.close();
      await dictionaryListDao.remove(path);
      await directory.delete(recursive: true);
    });

    await dictionary.init();

    final entry = await dictionary.readExactEntry("a");

    expect(entry?.content, "@@@LINK=a");
  });
}

Future<File> _writeMdx(
  Directory directory,
  List<(String, String)> entries,
) async {
  final orderedEntries = [...entries]..sort((a, b) => a.$1.compareTo(b.$1));
  final keyPayload = BytesBuilder();
  final recordPayload = BytesBuilder();
  var recordOffset = 0;

  for (final (key, value) in orderedEntries) {
    _writeUint32BE(keyPayload, recordOffset);
    keyPayload.add(utf8.encode(key));
    keyPayload.addByte(0);

    final valueBytes = utf8.encode(value);
    recordPayload.add(valueBytes);
    recordOffset += valueBytes.length;
  }

  final keyBlock = _block(keyPayload.toBytes());
  final keyInfo = BytesBuilder();
  _writeUint32BE(keyInfo, orderedEntries.length);
  keyInfo.add([0, 0]);
  _writeUint32BE(keyInfo, keyBlock.length);
  _writeUint32BE(keyInfo, keyBlock.length - 8);

  final recordBlock = _block(recordPayload.toBytes());
  final header = utf8.encode(
    '<Dictionary><Encoding="UTF-8" GeneratedByEngineVersion="1.0" '
    'Encrypted="No"/></Dictionary>\u0000',
  );

  final file = BytesBuilder();
  _writeUint32BE(file, header.length);
  file.add(header);
  _writeUint32LE(file, 0);

  _writeUint32BE(file, 1);
  _writeUint32BE(file, orderedEntries.length);
  _writeUint32BE(file, keyInfo.length);
  _writeUint32BE(file, keyBlock.length);
  file.add(keyInfo.toBytes());
  file.add(keyBlock);

  _writeUint32BE(file, 1);
  _writeUint32BE(file, orderedEntries.length);
  _writeUint32BE(file, 8);
  _writeUint32BE(file, recordBlock.length);
  _writeUint32BE(file, recordBlock.length);
  _writeUint32BE(file, recordBlock.length - 8);
  file.add(recordBlock);

  final result = File("${directory.path}/redirect.mdx");
  return result.writeAsBytes(file.toBytes());
}

List<int> _block(List<int> payload) {
  final builder = BytesBuilder();
  _writeUint32LE(builder, 0);
  _writeUint32BE(builder, 0);
  builder.add(payload);
  return builder.toBytes();
}

void _writeUint32BE(BytesBuilder builder, int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.big);
  builder.add(bytes.buffer.asUint8List());
}

void _writeUint32LE(BytesBuilder builder, int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.little);
  builder.add(bytes.buffer.asUint8List());
}

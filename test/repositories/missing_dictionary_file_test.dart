import "dart:io";

import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary_files.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart";

void main() {
  const mdxType = 1;

  late Directory directory;
  late String basePath;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp("missing_dict_file_");
    basePath = join(directory.path, "sample");
  });

  tearDown(() => directory.delete(recursive: true));

  Future<void> touch(String extension) =>
      File("$basePath$extension").writeAsString("");

  group("missingDictionaryFile", () {
    test("accepts an MDX dictionary whose file is there", () async {
      await touch(".mdx");

      expect(await missingDictionaryFile(basePath, mdxType), isNull);
    });

    test("names the missing MDX file", () async {
      expect(await missingDictionaryFile(basePath, mdxType), "sample.mdx");
    });

    test("accepts a StarDict dictionary with its three files", () async {
      await touch(".ifo");
      await touch(".idx");
      await touch(".dict");

      // The regression: a StarDict dictionary carries no `.mdx`, so the check
      // written for MDX deleted its registration as soon as it was switched
      // on (#766).
      expect(
        await missingDictionaryFile(basePath, DictionaryType.stardict),
        isNull,
      );
    });

    test("accepts the gzip-compressed index and body", () async {
      await touch(".ifo");
      await touch(".idx.gz");
      await touch(".dict.dz");

      expect(
        await missingDictionaryFile(basePath, DictionaryType.stardict),
        isNull,
      );
    });

    test("names the piece an incomplete StarDict dictionary lacks", () async {
      await touch(".ifo");
      await touch(".dict");

      expect(
        await missingDictionaryFile(basePath, DictionaryType.stardict),
        "sample.idx",
      );
    });

    test("treats a StarDict dictionary without .ifo as broken", () async {
      await touch(".idx");
      await touch(".dict");

      expect(
        await missingDictionaryFile(basePath, DictionaryType.stardict),
        "sample.ifo",
      );
    });
  });
}

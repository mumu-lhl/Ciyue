import "dart:io";

import "package:ciyue/repositories/dictionary.dart";
import "package:test/test.dart";

void main() {
  test("scans multiple folders recursively and removes duplicates", () async {
    final root = await Directory.systemTemp.createTemp("ciyue_dictionaries");
    addTearDown(() => root.delete(recursive: true));

    final first = Directory("${root.path}/first")..createSync();
    final nested = Directory("${first.path}/nested")..createSync();
    final second = Directory("${root.path}/second")..createSync();

    final firstDictionary = File("${first.path}/first.mdx")
      ..writeAsStringSync("");
    final nestedDictionary = File("${nested.path}/nested.MDX")
      ..writeAsStringSync("");
    final secondDictionary = File("${second.path}/second.mdx")
      ..writeAsStringSync("");
    File("${first.path}/not-a-dictionary.txt").writeAsStringSync("");

    final result = await findMdxFilesInDirectories([
      first.path,
      nested.path,
      second.path,
    ]);

    expect(
      result,
      [firstDictionary.path, nestedDictionary.path, secondDictionary.path]
        ..sort(),
    );
  });

  test("ignores folders that do not exist", () async {
    final result = await findMdxFilesInDirectories([
      "/path/that/does/not/exist",
    ]);

    expect(result, isEmpty);
  });
}

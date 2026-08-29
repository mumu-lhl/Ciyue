import "dart:io";

import "package:ciyue/repositories/hunspell.dart";
import "package:test/test.dart";

void main() {
  test("finds matching aff and dic files recursively", () async {
    final directory = await Directory.systemTemp.createTemp("ciyue_hunspell");
    addTearDown(() => directory.delete(recursive: true));

    final languageDirectory = Directory("${directory.path}/languages")
      ..createSync(recursive: true);
    File("${languageDirectory.path}/en_US.aff").writeAsStringSync("SET UTF-8");
    File("${languageDirectory.path}/en_US.dic").writeAsStringSync("0");
    File("${languageDirectory.path}/de_DE.AFF").writeAsStringSync("SET UTF-8");
    File("${languageDirectory.path}/de_DE.DIC").writeAsStringSync("0");
    File("${directory.path}/only.aff").writeAsStringSync("SET UTF-8");

    final pairs = await findHunspellPairs(directory);

    expect(pairs.map((pair) => pair.name), ["de_DE", "en_US"]);
    expect(pairs.map((pair) => pair.affPath), [
      "${languageDirectory.path}/de_DE.AFF",
      "${languageDirectory.path}/en_US.aff",
    ]);
  });
}

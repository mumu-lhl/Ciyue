import "dart:io";

import "package:hunspell_ffi/hunspell_ffi.dart";
import "package:test/test.dart";

String _fixturePath(String relativePath) {
  final primary = File(relativePath);
  if (primary.existsSync()) {
    return primary.absolute.path;
  }
  final nested = File("packages/hunspell_ffi/$relativePath");
  if (nested.existsSync()) {
    return nested.absolute.path;
  }
  return primary.absolute.path;
}

void main() {
  test("stems an inflected word", () {
    final dictionary = HunspellDictionary.open(
      affPath: _fixturePath("test/fixtures/simple.aff"),
      dicPath: _fixturePath("test/fixtures/simple.dic"),
    );
    addTearDown(dictionary.close);

    expect(dictionary.stem("rims"), contains("rim"));
    expect(dictionary.suggest("rimm"), contains("rim"));
  });

  test("returns all st: results for homonyms and multiple stems", () {
    final dictionary = HunspellDictionary.open(
      affPath: _fixturePath("test/fixtures/multiple_stems.aff"),
      dicPath: _fixturePath("test/fixtures/multiple_stems.dic"),
    );
    addTearDown(dictionary.close);

    expect(dictionary.stem("たい積"), unorderedEquals(["体積", "堆積", "滞積"]));
    expect(dictionary.stem("发"), unorderedEquals(["髮", "發"]));
    expect(dictionary.stem("mixed"), unorderedEquals(["stem1", "stem2"]));
  });

  test("supports two-pass stem lookup", () {
    final dictionary = HunspellDictionary.open(
      affPath: _fixturePath("test/fixtures/multiple_stems.aff"),
      dicPath: _fixturePath("test/fixtures/multiple_stems.dic"),
    );
    addTearDown(dictionary.close);

    expect(dictionary.stem("drunkest", twoPass: false), equals(["drunk"]));
    expect(
      dictionary.stem("drunkest", twoPass: true),
      unorderedEquals(["drunk", "drink"]),
    );
  });
}

import "dart:io";

import "package:hunspell_ffi/hunspell_ffi.dart";
import "package:test/test.dart";

void main() {
  test("stems an inflected word", () {
    final dictionary = HunspellDictionary.open(
      affPath: File("test/fixtures/simple.aff").absolute.path,
      dicPath: File("test/fixtures/simple.dic").absolute.path,
    );
    addTearDown(dictionary.close);

    expect(dictionary.stem("rims"), contains("rim"));
    expect(dictionary.suggest("rimm"), contains("rim"));
  });
}

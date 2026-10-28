import "dart:io";

import "package:ciyue/repositories/dictionary_import_failure.dart";
import "package:dict_reader/dict_reader.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("classifyDictionaryImportFailure", () {
    test("recognises the reader's compression exception", () {
      expect(
        classifyDictionaryImportFailure(UnsupportedCompressionException(1)),
        DictionaryImportFailure.unsupportedCompression,
      );
    });

    test("does not match on the message", () {
      // Until dict_reader#12 the reader threw a bare String, and the classifier
      // matched its text. That made the classification depend on wording, so a
      // string carrying the old message must now stay unknown — this fails if
      // message matching is ever reintroduced.
      expect(
        classifyDictionaryImportFailure("Compression method not supported"),
        DictionaryImportFailure.unknown,
      );
    });

    test("leaves every other failure unknown", () {
      expect(
        classifyDictionaryImportFailure(
          const FormatException("Not a .cidx file"),
        ),
        DictionaryImportFailure.unknown,
      );
      expect(
        classifyDictionaryImportFailure(
          const FileSystemException("No such file or directory"),
        ),
        DictionaryImportFailure.unknown,
      );
    });
  });
}

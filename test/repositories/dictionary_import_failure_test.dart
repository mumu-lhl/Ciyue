import "dart:io";

import "package:ciyue/repositories/dictionary_import_failure.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("classifyDictionaryImportFailure", () {
    test("recognises the LZO message while the reader throws a string", () {
      // The pinned reader throws a bare String, not an exception.
      expect(
        classifyDictionaryImportFailure("Compression method not supported"),
        DictionaryImportFailure.unsupportedCompression,
      );
    });

    test("recognises the typed form the reader will throw later", () {
      // Its toString keeps the wording, which is what the classifier reads.
      final error = FormatException(
        "Compression method not supported (method 1)",
      );

      expect(
        classifyDictionaryImportFailure(error),
        DictionaryImportFailure.unsupportedCompression,
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

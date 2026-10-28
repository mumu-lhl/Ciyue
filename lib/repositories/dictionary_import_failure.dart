/// Why a dictionary file could not be added.
///
/// The reader reports nearly everything as a format problem, which tells the
/// user nothing about what to do next. This separates the cases that do have a
/// next step from the ones that do not.
enum DictionaryImportFailure {
  /// The MDX blocks are LZO-compressed. Nothing is wrong with the file that
  /// converting it would not fix.
  unsupportedCompression,

  /// A corrupt file, a missing companion file, an I/O error: all the rest.
  unknown,
}

/// Classifies [error] by what the reader said.
///
/// The check reads the message rather than the type on purpose: the dependency
/// is pinned to a commit where the reader throws a bare String, and a typed
/// exception only arrives with the next reader release. Both forms keep the
/// same wording, so this recognises either, and can become a type check once
/// the pin moves — the test in `test/repositories/dictionary_import_failure_test.dart`
/// covers both shapes already.
DictionaryImportFailure classifyDictionaryImportFailure(Object error) {
  final message = error is String ? error : error.toString();
  if (message.contains("Compression method not supported")) {
    return DictionaryImportFailure.unsupportedCompression;
  }
  return DictionaryImportFailure.unknown;
}

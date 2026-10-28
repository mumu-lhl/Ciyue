import "package:dict_reader/dict_reader.dart";

/// Why a dictionary file could not be added.
///
/// The reader reports nearly everything as a format problem, which tells the
/// user nothing about what to do next. This separates the case that does have a
/// next step from the ones that do not.
enum DictionaryImportFailure {
  /// The MDX blocks are LZO-compressed. Nothing is wrong with the file that
  /// converting it would not fix.
  unsupportedCompression,

  /// A corrupt file, a missing companion file, an I/O error: all the rest.
  unknown,
}

/// Classifies [error] by what the reader threw.
///
/// [UnsupportedCompressionException] is the only failure with an action behind
/// it — convert the file and import it again — so it is the only one worth
/// putting on screen. Everything else stays [unknown]: a corrupt file and a
/// missing companion look the same from here, and neither suggests anything the
/// user could do.
///
/// The check is on the type, not the message: the wording of a reader error is
/// an implementation detail, and matching it silently turned this into a
/// dependency on that wording.
DictionaryImportFailure classifyDictionaryImportFailure(Object error) {
  if (error is UnsupportedCompressionException) {
    return DictionaryImportFailure.unsupportedCompression;
  }
  return DictionaryImportFailure.unknown;
}

import "dart:convert";
import "dart:ffi";

import "package:ffi/ffi.dart";

import "hunspell_ffi_bindings_generated.dart" as bindings;

class HunspellException implements Exception {
  final String message;

  const HunspellException(this.message);

  @override
  String toString() => "HunspellException: $message";
}

/// A loaded pair of Hunspell `.aff` and `.dic` files.
///
/// Calls are synchronous and must be serialized by the owner when the same
/// instance can be used by more than one caller. The C API returns UTF-8 data
/// for the dictionaries supported by Ciyue's first implementation.
class HunspellDictionary {
  final Pointer<Void> _handle;
  bool _isClosed = false;

  HunspellDictionary._(this._handle);

  factory HunspellDictionary.open({
    required String affPath,
    required String dicPath,
  }) {
    final nativeAffPath = affPath.toNativeUtf8(allocator: calloc);
    final nativeDicPath = dicPath.toNativeUtf8(allocator: calloc);

    try {
      final handle = bindings.ciyue_hunspell_create(
        nativeAffPath.cast<Char>(),
        nativeDicPath.cast<Char>(),
      );
      if (handle == nullptr) {
        throw HunspellException(
          "Failed to load Hunspell dictionary: $affPath, $dicPath",
        );
      }
      return HunspellDictionary._(handle);
    } finally {
      calloc.free(nativeAffPath);
      calloc.free(nativeDicPath);
    }
  }

  bool get isClosed => _isClosed;

  List<String> stem(String word) {
    return _query(word, bindings.ciyue_hunspell_stem);
  }

  List<String> suggest(String word) {
    return _query(word, bindings.ciyue_hunspell_suggest);
  }

  void close() {
    if (_isClosed) {
      return;
    }

    bindings.ciyue_hunspell_destroy(_handle);
    _isClosed = true;
  }

  List<String> _query(
    String word,
    int Function(
      Pointer<Void> handle,
      Pointer<Char> word,
      Pointer<Uint8> output,
      int outputCapacity,
    )
    query,
  ) {
    if (_isClosed) {
      throw const HunspellException("The Hunspell dictionary is closed");
    }

    final nativeWord = word.toNativeUtf8(allocator: calloc);
    try {
      var required = query(
        _handle,
        nativeWord.cast<Char>(),
        nullptr.cast<Uint8>(),
        0,
      );
      if (required == 0) {
        return [];
      }
      if (required < 0) {
        throw const HunspellException("Hunspell query failed");
      }

      for (var attempt = 0; attempt < 3; attempt++) {
        final output = calloc<Uint8>(required);
        try {
          final written = query(
            _handle,
            nativeWord.cast<Char>(),
            output,
            required,
          );
          if (written < 0) {
            throw const HunspellException("Hunspell query failed");
          }
          if (written == 0) {
            return [];
          }
          if (written <= required) {
            return _decodeResults(output, written);
          }
          required = written;
        } finally {
          calloc.free(output);
        }
      }

      throw const HunspellException("Hunspell result changed repeatedly");
    } finally {
      calloc.free(nativeWord);
    }
  }

  List<String> _decodeResults(Pointer<Uint8> output, int length) {
    final bytes = output.asTypedList(length);
    final results = <String>[];
    var start = 0;

    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != 0) {
        continue;
      }

      if (i == start) {
        break;
      }

      results.add(utf8.decode(bytes.sublist(start, i)));
      start = i + 1;
    }

    return results;
  }
}

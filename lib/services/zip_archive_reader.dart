import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:archive/archive.dart";

/// Reads single entries from a zip archive on demand.
///
/// Only the archive's central directory is read up front; each entry's data
/// is seeked to and inflated only when requested, so a multi-gigabyte
/// archive never has to be unpacked or held in memory. Entry reads are
/// serialized: the underlying file stream has one shared position.
///
/// Entry names are matched after normalization (backslashes become slashes,
/// `.` and empty segments drop out). Names escaping the archive root with
/// `..` are never indexed, so a hostile archive cannot smuggle an entry
/// past the caller. Lookups try the exact normalized name first, then a
/// case-insensitive match, mirroring how loosely the dictionary formats
/// treat resource key spellings.
class ZipArchiveReader {
  ZipArchiveReader(File file) : _file = file;

  final File _file;

  InputFileStream? _input;
  Map<String, ZipFileHeader>? _index;
  Map<String, ZipFileHeader>? _lowercaseIndex;
  Future<void> _gate = Future<void>.value();
  bool _closed = false;

  /// The entry's decompressed bytes, or null when the archive has no
  /// readable entry under [name]. A missing, unreadable, or corrupt archive
  /// also reads as null: callers fall through to their next source.
  Future<Uint8List?> readEntry(String name) => _synchronized(() {
    final header = _headerFor(name);
    if (header?.file == null) return null;
    try {
      return header!.file!.readBytes();
    } catch (_) {
      return null;
    }
  });

  /// Whether the archive contains a readable entry under [name], without
  /// inflating it.
  Future<bool> containsEntry(String name) => _synchronized(() {
    final header = _headerFor(name);
    return header?.file != null;
  });

  /// Runs [action] with exclusive access to the shared file stream. The
  /// action itself is synchronous file work; the gate only orders the
  /// calls, since concurrent entry reads would race the stream position.
  Future<T> _synchronized<T>(T Function() action) {
    final run = _gate.then((_) => action());
    _gate = run.then((_) {}, onError: (_) {});
    return run;
  }

  ZipFileHeader? _headerFor(String name) {
    if (_closed) return null;
    final normalized = _normalizeEntryName(name);
    if (normalized == null) return null;
    final index = _ensureIndex();
    if (index == null) return null;
    return index[normalized] ?? _lowercaseIndex?[normalized.toLowerCase()];
  }

  /// Parses the central directory once and caches the name index. Returns
  /// null when the file is missing or is not a readable zip; the failure is
  /// cached too, since the archive is not expected to appear mid-lifetime.
  Map<String, ZipFileHeader>? _ensureIndex() {
    final cached = _index;
    if (cached != null) return cached;
    if (_closed) return null;
    try {
      if (!_file.existsSync()) {
        _index = const {};
        _lowercaseIndex = const {};
        return _index;
      }
      _input ??= InputFileStream(_file.path);
      final directory = ZipDirectory()..read(_input!);
      final index = <String, ZipFileHeader>{};
      final lowercaseIndex = <String, ZipFileHeader>{};
      for (final header in directory.fileHeaders) {
        final normalized = _normalizeEntryName(header.filename);
        if (normalized == null || header.file == null) continue;
        index.putIfAbsent(normalized, () => header);
        lowercaseIndex.putIfAbsent(normalized.toLowerCase(), () => header);
      }
      _index = index;
      _lowercaseIndex = lowercaseIndex;
      return index;
    } catch (_) {
      _closeInput();
      _index = const {};
      _lowercaseIndex = const {};
      return _index;
    }
  }

  /// Releases the file handle. Later reads return null.
  void close() {
    _closed = true;
    _closeInput();
  }

  void _closeInput() {
    final input = _input;
    _input = null;
    if (input != null) {
      try {
        input.closeSync();
      } catch (_) {
        // Best effort: the handle is dropped either way.
      }
    }
  }
}

/// Normalizes a zip entry or lookup name to slash-separated segments, or
/// null when the name is empty or escapes the archive root.
String? _normalizeEntryName(String name) {
  final segments = name.replaceAll("\\", "/").split("/");
  final kept = <String>[];
  for (final segment in segments) {
    if (segment.isEmpty || segment == ".") continue;
    if (segment == "..") return null;
    kept.add(segment);
  }
  if (kept.isEmpty) return null;
  return kept.join("/");
}

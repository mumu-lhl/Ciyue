import "package:dict_reader/dict_reader.dart";

final _mddReaders = <String, Future<DictReader>>{};

Future<DictReader> mddReaderFor(String path) async {
  final existing = _mddReaders[path];
  if (existing != null) {
    return existing;
  }

  final reader = DictReader(path);
  final future = _initializeReader(reader);
  _mddReaders[path] = future;

  try {
    return await future;
  } catch (_) {
    if (identical(_mddReaders[path], future)) {
      _mddReaders.remove(path);
    }
    rethrow;
  }
}

Future<DictReader> _initializeReader(DictReader reader) async {
  try {
    await reader.initDict();
    return reader;
  } catch (_) {
    await reader.close();
    rethrow;
  }
}

Future<void> closeMddReader(String path) async {
  final future = _mddReaders.remove(path);
  if (future == null) {
    return;
  }

  try {
    final reader = await future;
    await reader.close();
  } catch (_) {
    // A failed initialization has already closed its reader.
  }
}

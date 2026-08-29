import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/hunspell.dart";
import "package:hunspell_ffi/hunspell_ffi.dart";

abstract interface class MorphologyProvider {
  Future<List<String>> stems(String word);

  Future<List<String>> suggestions(String word);
}

final hunspellManager = HunspellManager();

class HunspellManager implements MorphologyProvider {
  final List<_LoadedSource> _loadedSources = [];
  final Map<int, String> errors = {};
  Future<void> _operationTail = Future<void>.value();

  int get loadedSourceCount => _loadedSources.length;

  Future<void> reloadFromDatabase() async {
    final sources = await hunspellSourceDao.all();
    await reload(
      sources.map(
        (source) => HunspellSourceInfo(
          id: source.id,
          name: source.name,
          affPath: source.affPath,
          dicPath: source.dicPath,
          language: source.language,
          enabled: source.enabled,
          order: source.order,
        ),
      ),
    );
  }

  Future<void> reload(Iterable<HunspellSourceInfo> sources) {
    final sourceList = sources.toList(growable: false);
    return _enqueue(() async {
      _closeLoadedSources();
      errors.clear();

      for (final source in sourceList) {
        if (!source.enabled) {
          continue;
        }

        if (!await File(source.affPath).exists() ||
            !await File(source.dicPath).exists()) {
          errors[source.id] = "Hunspell files are missing";
          continue;
        }

        try {
          final dictionary = HunspellDictionary.open(
            affPath: source.affPath,
            dicPath: source.dicPath,
          );
          _loadedSources.add(
            _LoadedSource(source: source, dictionary: dictionary),
          );
        } catch (error) {
          errors[source.id] = error.toString();
        }
      }
    });
  }

  @override
  Future<List<String>> stems(String word) {
    return _enqueue(() {
      final results = <String>{};
      for (final loaded in _loadedSources) {
        results.addAll(loaded.dictionary.stem(word));
      }
      return results.toList(growable: false);
    });
  }

  @override
  Future<List<String>> suggestions(String word) {
    return _enqueue(() {
      final results = <String>{};
      for (final loaded in _loadedSources) {
        results.addAll(loaded.dictionary.suggest(word));
      }
      return results.toList(growable: false);
    });
  }

  Future<void> close() {
    return _enqueue(() {
      _closeLoadedSources();
      errors.clear();
    });
  }

  void _closeLoadedSources() {
    for (final loaded in _loadedSources) {
      loaded.dictionary.close();
    }
    _loadedSources.clear();
  }

  Future<T> _enqueue<T>(FutureOr<T> Function() operation) {
    final completer = Completer<T>();

    _operationTail = _operationTail.then<void>((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }
}

class _LoadedSource {
  final HunspellSourceInfo source;
  final HunspellDictionary dictionary;

  const _LoadedSource({required this.source, required this.dictionary});
}

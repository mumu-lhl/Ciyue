import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/hunspell.dart";
import "package:hunspell_ffi/hunspell_ffi.dart";

abstract interface class MorphologyProvider {
  Future<List<String>> stems(String word);

  Future<List<String>> suggestions(String word);
}

class _LoadedHunspellSource {
  final HunspellSourceInfo source;
  final HunspellDictionary dictionary;

  const _LoadedHunspellSource({required this.source, required this.dictionary});
}

final hunspellManager = HunspellManager();

class HunspellManager implements MorphologyProvider {
  final List<_LoadedHunspellSource> _loadedSources = [];
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
          twoPassLookup: source.twoPassLookup,
        ),
      ),
    );
  }

  Future<void> reload(Iterable<HunspellSourceInfo> sources) {
    final sourceList = sources.toList(growable: false);
    return _enqueue(() async {
      _closeLoadedDictionaries();
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
            _LoadedHunspellSource(source: source, dictionary: dictionary),
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
      final trimmed = word.trim();
      if (trimmed.isEmpty) {
        return const <String>[];
      }

      final tokens = trimmed.split(RegExp(r"\s+"));
      if (tokens.length == 1) {
        return _singleWordStems(trimmed);
      }

      return _phraseStems(tokens, trimmed);
    });
  }

  List<String> _singleWordStems(String word) {
    final results = <String>{};
    for (final item in _loadedSources) {
      results.addAll(
        item.dictionary.stem(word, twoPass: item.source.twoPassLookup),
      );
    }
    return results.toList(growable: false);
  }

  List<String> _phraseStems(List<String> tokens, String originalPhrase) {
    const maxPhraseWords = 5;
    const maxCombinations = 32;

    if (tokens.length > maxPhraseWords) {
      return _singleWordStems(originalPhrase);
    }

    final direct = _singleWordStems(originalPhrase);

    var hasAnyStem = false;
    final tokenCandidates = <List<String>>[];
    for (final token in tokens) {
      final stems = _singleWordStems(token);
      if (stems.isNotEmpty && !(stems.length == 1 && stems.first == token)) {
        hasAnyStem = true;
      }
      tokenCandidates.add(<String>{token, ...stems}.toList(growable: false));
    }

    if (!hasAnyStem) {
      return direct;
    }

    final normalizedOriginal = tokens.join(" ");
    final results = <String>{...direct};

    var combinations = <List<String>>[[]];
    for (final candidates in tokenCandidates) {
      final next = <List<String>>[];
      for (final prefix in combinations) {
        for (final candidate in candidates) {
          next.add([...prefix, candidate]);
          if (next.length >= maxCombinations) {
            break;
          }
        }
        if (next.length >= maxCombinations) {
          break;
        }
      }
      combinations = next;
    }

    for (final combo in combinations) {
      final phrase = combo.join(" ");
      if (phrase.toLowerCase() != normalizedOriginal.toLowerCase()) {
        results.add(phrase);
      }
    }

    return results.toList(growable: false);
  }

  @override
  Future<List<String>> suggestions(String word) {
    return _enqueue(() {
      final results = <String>{};
      for (final item in _loadedSources) {
        results.addAll(item.dictionary.suggest(word));
      }
      return results.toList(growable: false);
    });
  }

  Future<void> close() {
    return _enqueue(() {
      _closeLoadedDictionaries();
      errors.clear();
    });
  }

  void _closeLoadedDictionaries() {
    for (final item in _loadedSources) {
      item.dictionary.close();
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

import "dart:async";
import "dart:io";
import "dart:isolate";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/hunspell.dart";
import "package:dict_reader/dict_reader.dart" show normalizeKey;
import "package:hunspell_ffi/hunspell_ffi.dart";

/// What [HunspellManager.errors] holds for a source whose files have gone.
///
/// The loader runs in an isolate with no `BuildContext`, so it cannot translate
/// this itself; it reports the marker and the UI turns it into a string.
const hunspellFilesMissingMarker = "hunspell:files-missing";

abstract interface class MorphologyProvider {
  Future<List<String>> stems(String word);

  Future<List<String>> suggestions(String word);
}

class _LoadedHunspellSource {
  final HunspellSourceInfo source;
  final HunspellDictionary dictionary;

  const _LoadedHunspellSource({required this.source, required this.dictionary});
}

// Worker isolate messages. All cross-isolate data must be simple values.
class _ReloadRequest {
  final List<HunspellSourceInfo> sources;
  final SendPort replyPort;

  const _ReloadRequest(this.sources, this.replyPort);
}

class _ReloadResult {
  final int loadedCount;
  final Map<int, String> errors;

  const _ReloadResult(this.loadedCount, this.errors);
}

class _StemsRequest {
  final String word;
  final SendPort replyPort;

  const _StemsRequest(this.word, this.replyPort);
}

class _SuggestionsRequest {
  final String word;
  final SendPort replyPort;

  const _SuggestionsRequest(this.word, this.replyPort);
}

class _CloseRequest {
  final SendPort replyPort;

  const _CloseRequest(this.replyPort);
}

/// Worker isolate entry point. Owns all HunspellDictionary native handles
/// so synchronous FFI calls never run on the UI thread.
///
/// Read/write separation: `stems`/`suggestions` always use the currently
/// active dictionaries. A `reload` loads new dictionaries asynchronously
/// without blocking the message loop, so queries keep serving (with the old
/// dictionaries) instead of head-of-line blocking behind a slow reload.
void _hunspellWorker(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  var dictionaries = <_LoadedHunspellSource>[];
  var errors = <int, String>{};
  var reloadInProgress = false;
  // Pending reload request that arrived while a reload was in progress.
  // Latest-wins: only the most recent pending request is kept.
  _ReloadRequest? pendingReload;

  Future<_ReloadResult> doReload(List<HunspellSourceInfo> sources) async {
    final newDictionaries = <_LoadedHunspellSource>[];
    final newErrors = <int, String>{};

    for (final source in sources) {
      if (!source.enabled) continue;

      if (!await File(source.affPath).exists() ||
          !await File(source.dicPath).exists()) {
        newErrors[source.id] = hunspellFilesMissingMarker;
        continue;
      }

      try {
        final dictionary = HunspellDictionary.open(
          affPath: source.affPath,
          dicPath: source.dicPath,
        );
        newDictionaries.add(
          _LoadedHunspellSource(source: source, dictionary: dictionary),
        );
      } catch (error) {
        newErrors[source.id] = error.toString();
      }
    }

    // Atomically swap: close old dictionaries only after new ones are ready.
    for (final item in dictionaries) {
      item.dictionary.close();
    }
    dictionaries = newDictionaries;
    errors = newErrors;

    return _ReloadResult(dictionaries.length, Map.of(errors));
  }

  List<String> doStems(String word) {
    // Hunspell compares bytes against the `.dic`, and those files are written
    // in composed form (NFC) — see docs/guide/word-forms.md. A query that
    // arrived decomposed would silently find nothing, so normalise once here,
    // for every caller, rather than asking each of them to remember.
    final trimmed = normalizeKey(word).trim();
    if (trimmed.isEmpty) return const <String>[];

    final tokens = trimmed.split(RegExp(r"\s+"));
    if (tokens.length == 1) {
      return _singleWordStems(dictionaries, trimmed);
    }
    return _phraseStems(dictionaries, tokens, trimmed);
  }

  List<String> doSuggestions(String word) {
    // Same reason as `doStems`: a decomposed spelling is a misspelling as far
    // as the byte-level word list is concerned, and the candidates it gets back
    // would have nothing to do with the word that was typed.
    final normalized = normalizeKey(word);
    final results = <String>{};
    for (final item in dictionaries) {
      results.addAll(item.dictionary.suggest(normalized));
    }
    return results.toList(growable: false);
  }

  receivePort.listen((message) {
    if (message is _ReloadRequest) {
      if (reloadInProgress) {
        // Latest-wins: queue the newest request, drop any older pending one.
        // The previous pending request's reply port will get the result of
        // the latest reload (or we could reply immediately, but waiting for
        // the latest is more correct).
        final oldPending = pendingReload;
        pendingReload = message;
        // Reply to the superseded request immediately to avoid hanging it.
        oldPending?.replyPort.send(
          _ReloadResult(dictionaries.length, Map.of(errors)),
        );
        return;
      }
      reloadInProgress = true;
      // Don't await: keep serving queries with the old dictionaries
      // while the new ones load.
      doReload(message.sources).then((result) {
        message.replyPort.send(result);
        // Process pending reload if one arrived during this reload.
        final pending = pendingReload;
        pendingReload = null;
        if (pending != null) {
          doReload(pending.sources).then((pendingResult) {
            reloadInProgress = false;
            pending.replyPort.send(pendingResult);
          });
        } else {
          reloadInProgress = false;
        }
      });
    } else if (message is _StemsRequest) {
      message.replyPort.send(doStems(message.word));
    } else if (message is _SuggestionsRequest) {
      message.replyPort.send(doSuggestions(message.word));
    } else if (message is _CloseRequest) {
      for (final item in dictionaries) {
        item.dictionary.close();
      }
      dictionaries = [];
      errors = {};
      message.replyPort.send(null);
      receivePort.close();
    }
  });
}

List<String> _singleWordStems(
  List<_LoadedHunspellSource> dictionaries,
  String word,
) {
  final results = <String>{};
  for (final item in dictionaries) {
    results.addAll(
      item.dictionary.stem(word, twoPass: item.source.twoPassLookup),
    );
  }
  return results.toList(growable: false);
}

List<String> _phraseStems(
  List<_LoadedHunspellSource> dictionaries,
  List<String> tokens,
  String originalPhrase,
) {
  const maxPhraseWords = 5;
  const maxCombinations = 32;

  if (tokens.length > maxPhraseWords) {
    return _singleWordStems(dictionaries, originalPhrase);
  }

  final direct = _singleWordStems(dictionaries, originalPhrase);

  var hasAnyStem = false;
  final tokenCandidates = <List<String>>[];
  for (final token in tokens) {
    final stems = _singleWordStems(dictionaries, token);
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
        if (next.length >= maxCombinations) break;
      }
      if (next.length >= maxCombinations) break;
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

final hunspellManager = HunspellManager();

/// Hunspell morphology provider backed by a dedicated worker isolate.
///
/// All native HunspellDictionary handles live in the worker isolate, so the
/// synchronous FFI calls in `stems`/`suggestions` never block the UI thread.
/// Reloads run asynchronously in the worker without head-of-line blocking
/// queries (queries keep using the previous dictionaries until the reload
/// completes and swaps atomically).
class HunspellManager implements MorphologyProvider {
  SendPort? _workerPort;
  Future<void>? _spawnFuture;

  int _loadedSourceCount = 0;
  final Map<int, String> errors = {};

  int get loadedSourceCount => _loadedSourceCount;

  Future<SendPort> _ensureWorker() async {
    final existing = _workerPort;
    if (existing != null) return existing;

    var spawn = _spawnFuture;
    if (spawn == null) {
      final receivePort = ReceivePort();
      spawn = Isolate.spawn(_hunspellWorker, receivePort.sendPort)
          .then((_) async {
            final port = await receivePort.first as SendPort;
            // Only assign if not closed during spawn (avoids zombie worker).
            if (_spawnFuture != null) {
              _workerPort = port;
            } else {
              // Closed during spawn; tell the new worker to shut down.
              final cleanupPort = ReceivePort();
              port.send(_CloseRequest(cleanupPort.sendPort));
              await cleanupPort.first;
              cleanupPort.close();
            }
          })
          .catchError((e) {
            // Clear failed spawn so next call retries instead of permanently failing.
            if (_spawnFuture == spawn) {
              _spawnFuture = null;
            }
            throw e;
          });
      _spawnFuture = spawn;
    }
    await spawn;
    final worker = _workerPort;
    if (worker == null) {
      // Closed during spawn; retry (will spawn a new worker).
      _spawnFuture = null;
      return _ensureWorker();
    }
    return worker;
  }

  Future<T> _request<T>(Object Function(SendPort) buildRequest) async {
    final worker = await _ensureWorker();
    final replyPort = ReceivePort();
    worker.send(buildRequest(replyPort.sendPort));
    try {
      return await replyPort.first as T;
    } finally {
      replyPort.close();
    }
  }

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

  Future<void> reload(Iterable<HunspellSourceInfo> sources) async {
    final result = await _request<_ReloadResult>(
      (reply) => _ReloadRequest(sources.toList(growable: false), reply),
    );
    _loadedSourceCount = result.loadedCount;
    errors
      ..clear()
      ..addAll(result.errors);
  }

  @override
  Future<List<String>> stems(String word) {
    return _request<List<String>>((reply) => _StemsRequest(word, reply));
  }

  @override
  Future<List<String>> suggestions(String word) {
    return _request<List<String>>((reply) => _SuggestionsRequest(word, reply));
  }

  Future<void> close() async {
    final worker = _workerPort;
    _workerPort = null;
    _spawnFuture = null;
    _loadedSourceCount = 0;
    errors.clear();
    if (worker != null) {
      final replyPort = ReceivePort();
      worker.send(_CloseRequest(replyPort.sendPort));
      await replyPort.first;
      replyPort.close();
    }
  }
}

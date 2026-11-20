import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/media_tags.dart";
import "package:mime/mime.dart";

/// The MIME type [dict] declares for [filename], if its format carries one.
/// Formats that only have a file name return null, so callers keep the
/// extension-based guess. Kept as a capability check rather than an interface
/// member: only ZIM stores a MIME type per entry.
Future<String?> declaredResourceMimeType(
  LoadedDictionary dict,
  String filename,
) async {
  if (dict is BaseLoadedDictionary) {
    return await dict.resourceMimeType(filename);
  }
  return null;
}

/// The headword of the article at [path] in a format that serves its HTML
/// through the local HTTP server, or null when [path] is a resource (or not
/// part of this dictionary). Lets a navigation to a local article URL (a
/// `meta refresh` redirect, for instance) go through the normal lookup flow
/// instead of rendering the raw HTML.
Future<String?> declaredEntryTitleAtPath(
  LoadedDictionary dict,
  String path,
) async {
  if (dict is BaseLoadedDictionary) {
    return await dict.entryTitleAtPath(path);
  }
  return null;
}

/// A base implementation of [LoadedDictionary] providing common lifecycle,
/// desktop HTTP server management, asynchronous loading coordination, and
/// common dictionary lookup helpers.
abstract class BaseLoadedDictionary implements LoadedDictionary {
  @override
  late int id;

  @override
  final String path;

  @override
  late String title;

  // Not final: close() resets the cached futures so a later init() runs
  // the metadata load again, and that load assigns the type a second
  // time (P1-6). A `late final` would throw on the re-init, exactly like
  // the `entriesTotal` case below.
  @override
  late int type;

  // Metadata-only and full initialization can both run for the same
  // dictionary, so this is assigned more than once; `late final` would throw
  // "Field 'entriesTotal' has already been initialized" on the second pass.
  @override
  late int entriesTotal;

  @override
  int port = 0;

  HttpServer? server;
  bool _serverInitialized = false;

  bool _isLoading = true;

  @override
  bool get isLoading => _isLoading;
  set isLoading(bool value) {
    _isLoading = value;
    if (!value) {
      _loadingCompleter?.complete();
      _loadingCompleter = null;
    }
  }

  Completer<void>? _loadingCompleter;
  Future<void>? metadataInitialization;
  Future<void>? initialization;
  Future<void>? _closeFuture;
  Object? initializationError;

  /// True once [close] has started. An initialization still in flight must
  /// see this before it reaches [startDesktopServer], or it would bind a
  /// server after the close that nobody ever closes again (P1-4).
  bool _closed = false;

  /// Counts close/init cycles. [startDesktopServer] refuses to bind when
  /// the generation it was started under no longer matches, so a stale
  /// initialization cannot resurrect a server after a close or a restart.
  int _generation = 0;

  /// Test-only hook: replaces the loopback bind in [startDesktopServer]
  /// so a bind failure can be simulated without occupying ports (P1-17).
  Future<HttpServer> Function(InternetAddress address, int port)?
  bindServerForTest;

  @override
  bool get isReady =>
      initialization != null && !isLoading && initializationError == null;

  BaseLoadedDictionary({required this.path});

  @override
  Future<void> waitForLoading() async {
    final init = initialization ?? metadataInitialization;
    if (init != null) {
      await init;
      return;
    }
    if (!isLoading) {
      return;
    }
    await (_loadingCompleter ??= Completer<void>()).future;
  }

  @override
  Future<void> close({bool waitForLoading = true}) {
    final existing = _closeFuture;
    if (existing != null) {
      return existing;
    }
    return _closeFuture = _closeInternal(waitForLoading: waitForLoading);
  }

  Future<void> _closeInternal({bool waitForLoading = true}) async {
    // Mark closed synchronously, before any await: an initialization
    // still in flight must see this before it reaches
    // [startDesktopServer], or it would bind a server after this close
    // that nobody ever closes again. The generation bump invalidates
    // that initialization even if it already passed the check once.
    _closed = true;
    _generation++;
    try {
      // Only wait when loading was actually started: for a dictionary that was
      // never initialized, both futures are null and isLoading is still its
      // initial true, so waitForLoading() would await a completer nothing ever
      // completes. The pre-refactor close awaited initialization only when
      // non-null; keep that behavior.
      if (waitForLoading &&
          (initialization != null || metadataInitialization != null)) {
        try {
          await this.waitForLoading();
        } catch (_) {}
      }

      if (_serverInitialized) {
        try {
          await server?.close(force: true);
        } catch (e) {
          talker.error("Error closing HTTP server on port $port: $e");
        } finally {
          server = null;
          _serverInitialized = false;
          port = 0;
        }
      }

      await onClose();
    } finally {
      // Let a later init() start over instead of returning the stale
      // futures of a closed dictionary (P1-6): a re-initialized
      // dictionary must run its metadata load and bind a fresh server.
      // [_closeFuture] stays memoized, so a second close() while no new
      // init has started returns the same future instead of running
      // [onClose] a second time.
      initialization = null;
      metadataInitialization = null;
      initializationError = null;
    }
  }

  /// Starts a new initialization cycle, e.g. after [close] reset the
  /// cached futures. Clears the closed flag and the memoized close
  /// future, and returns the generation the new cycle must pass to
  /// [startDesktopServer] so a close in the meantime invalidates it.
  /// Subclass [_initialize] methods call this as their first statement.
  int beginInitialization() {
    _closed = false;
    _closeFuture = null;
    return ++_generation;
  }

  /// Hook for subclasses to release reader resources.
  Future<void> onClose();

  /// MDict and StarDict articles are HTML fragments, so they need an injected
  /// doctype to render in standards mode. ZIM articles are complete pages and
  /// opt out to keep whatever document mode the archive's author chose.
  bool get useStandardsMode => true;

  /// Applies this format's document mode. Formats that override
  /// [wrapContentWithResources] call it too, so an injected doctype stays
  /// ahead of any stylesheet/script tags they prepend.
  String applyDocumentMode(String html) =>
      useStandardsMode ? forceStandardsMode(html) : html;

  @override
  String wrapContentWithResources(String content) =>
      applyDocumentMode(rewriteMediaTags(content));

  /// MIME type declared by the dictionary format for [filename], or null when
  /// the format does not carry one. Resource handlers fall back to guessing
  /// from the file name when this is null.
  Future<String?> resourceMimeType(String filename) async => null;

  /// The headword of the article at a local-server [path], or null when the
  /// path is a resource or unknown. Formats that do not serve article HTML
  /// over the local server keep the default.
  Future<String?> entryTitleAtPath(String path) async => null;

  @override
  Future<String?> resolveExactKey(String word) async {
    final resolved = await resolveKeys([word]);
    return resolved[word];
  }

  @override
  Future<void> removeDictionary({int? dictionaryId}) async {
    await dictionaryListDao.remove(path);
    await onRemove();
  }

  /// Hook for subclasses to remove cached indices or files.
  Future<void> onRemove() async {}

  /// Serves entry HTML and static assets to the WebView on Desktop.
  ///
  /// [generation] is the value [beginInitialization] returned for the
  /// initialization cycle calling this: when a [close] (or a newer init)
  /// has bumped the generation since, binding is refused instead of
  /// leaking a server nobody will close. A bind failure is logged and
  /// rethrown so the caller's `_initialize` records it in
  /// [initializationError] and [isReady] turns false, instead of the
  /// dictionary silently reporting ready with [port] still 0.
  Future<void> startDesktopServer({
    Future<Uint8List?> Function(String filename)? onReadResource,
    Future<Stream<List<int>>?> Function(String filename)? onReadResourceStream,
    int? generation,
  }) async {
    if (_closed || (generation != null && generation != _generation)) {
      throw StateError(
        "Dictionary $path is closed; refusing to start a desktop server",
      );
    }
    try {
      server =
          await (bindServerForTest?.call(InternetAddress.loopbackIPv4, 0) ??
              HttpServer.bind(InternetAddress.loopbackIPv4, 0));
      if (_closed || (generation != null && generation != _generation)) {
        // Bound while a close landed: shut it down at once, nobody else
        // will.
        await server?.close(force: true);
        server = null;
        port = 0;
        throw StateError(
          "Dictionary $path was closed while starting its desktop server",
        );
      }
      _serverInitialized = true;
      port = server!.port;
      talker.info("HTTP server started on port $port");

      server!.listen((HttpRequest request) async {
        if (request.method == "POST" && request.uri.path == "/") {
          final body = await utf8.decoder.bind(request).join();
          final jsonData = json.decode(body);
          final content = jsonData["content"];
          try {
            request.response
              ..headers.contentType = ContentType.html
              ..write(content);
            await request.response.close();
            return;
          } catch (_) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }
        } else if (request.method == "GET" && request.uri.path != "/") {
          final filename = Uri.decodeComponent(request.uri.path.substring(1));
          final mime =
              await resourceMimeType(filename) ??
              lookupMimeType(filename) ??
              "application/octet-stream";
          if (onReadResourceStream != null) {
            try {
              final stream = await onReadResourceStream(filename);
              if (stream != null) {
                request.response.headers.contentType = ContentType.parse(mime);
                await request.response.addStream(stream);
                await request.response.close();
                return;
              }
            } catch (_) {}
          }
          if (onReadResource != null) {
            try {
              final data = await onReadResource(filename);
              if (data != null) {
                request.response
                  ..headers.contentType = ContentType.parse(mime)
                  ..add(data);
                await request.response.close();
                return;
              }
            } catch (_) {}
          }
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
      });
    } catch (e, stackTrace) {
      if (_serverInitialized) {
        try {
          await server?.close(force: true);
        } catch (_) {}
      }
      server = null;
      _serverInitialized = false;
      port = 0;
      // A failed bind used to be swallowed here, so the dictionary kept
      // reporting isReady with port 0 and the word page rendered a blank
      // body with no diagnosis. Log it and let the caller record it.
      talker.error(
        "Failed to start desktop server for $path: $e",
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}

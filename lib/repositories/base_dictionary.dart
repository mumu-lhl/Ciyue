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

  @override
  late final int type;

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
  }

  /// Hook for subclasses to release reader resources.
  Future<void> onClose();

  @override
  String wrapContentWithResources(String content) => rewriteMediaTags(content);

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
  Future<void> startDesktopServer({
    Future<Uint8List?> Function(String filename)? onReadResource,
    Future<Stream<List<int>>?> Function(String filename)? onReadResourceStream,
  }) async {
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
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
              ..write(content)
              ..close();
            return;
          } catch (_) {
            request.response
              ..statusCode = HttpStatus.notFound
              ..close();
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
                  ..add(data)
                  ..close();
                return;
              }
            } catch (_) {}
          }
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
          return;
        }
      });
    } catch (e) {
      if (_serverInitialized) {
        await server?.close(force: true);
      }
    }
  }
}

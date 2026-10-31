import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/media_tags.dart";
import "package:mime/mime.dart";

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

  @override
  late final int entriesTotal;

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
          if (onReadResourceStream != null) {
            try {
              final stream = await onReadResourceStream(filename);
              if (stream != null) {
                request.response.headers.contentType = ContentType.parse(
                  lookupMimeType(filename) ?? "application/octet-stream",
                );
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
                  ..headers.contentType = ContentType.parse(
                    lookupMimeType(filename) ?? "application/octet-stream",
                  )
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

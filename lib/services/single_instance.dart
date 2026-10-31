import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/command_line.dart";
import "package:path_provider/path_provider.dart";

/// Message forwarded from a second process to the running instance.
class SingleInstanceMessage {
  const SingleInstanceMessage({
    required this.token,
    required this.options,
    this.bringToFront = true,
  });

  final String token;
  final CommandLineOptions options;
  final bool bringToFront;

  Map<String, Object?> toJson() => {
    "token": token,
    "options": options.toJson(),
    "bringToFront": bringToFront,
  };

  factory SingleInstanceMessage.fromJson(Map<String, Object?> json) {
    final rawOptions = json["options"];
    return SingleInstanceMessage(
      token: json["token"] as String? ?? "",
      options: rawOptions is Map
          ? CommandLineOptions.fromJson(
              rawOptions.map((key, value) => MapEntry("$key", value)),
            )
          : const CommandLineOptions(),
      bringToFront: json["bringToFront"] as bool? ?? true,
    );
  }
}

/// Cross-platform single-instance guard for the desktop app.
///
/// The primary instance listens on the loopback interface and writes its port
/// and a random token to a lock file in the application support directory.
/// Later launches read that file, forward their parsed options to the primary
/// instance, and exit.
///
/// Only the loopback interface is exposed and every message must carry the
/// token from the lock file, so unrelated local processes cannot drive the
/// app by guessing the port.
class SingleInstance {
  SingleInstance({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static const _lockFileName = "single_instance.json";

  /// Preferred port. Falls back to an ephemeral port when it is taken.
  static const _defaultPort = 47116;
  static const _connectTimeout = Duration(milliseconds: 500);
  static const _handshakeTimeout = Duration(seconds: 2);

  final Future<Directory> Function() _supportDirectory;

  ServerSocket? _server;
  File? _lockFile;
  Future<void> Function(CommandLineOptions options)? _handler;
  final List<CommandLineOptions> _pending = [];
  bool _disposed = false;

  /// Returns `true` when this process is the primary instance.
  ///
  /// Returns `false` after successfully forwarding [options] to the running
  /// instance; the caller should exit in that case.
  Future<bool> ensurePrimary(CommandLineOptions options) async {
    final lockFile = await _resolveLockFile();
    _lockFile = lockFile;

    final existing = await _readLock(lockFile);
    if (existing != null) {
      if (await _forward(existing, options)) {
        return false;
      }
      // The owner is gone but its lock file is still there; take over.
      await _deleteLock(lockFile);
    }

    await _listen(lockFile);
    return true;
  }

  /// Registers the UI handler and flushes messages received during startup.
  void setHandler(Future<void> Function(CommandLineOptions options) handler) {
    _handler = handler;
    final pending = List<CommandLineOptions>.of(_pending);
    _pending.clear();
    for (final options in pending) {
      unawaited(_dispatch(options));
    }
  }

  /// Stops listening and removes the lock file.
  Future<void> dispose() async {
    _disposed = true;
    _handler = null;
    _pending.clear();
    await _server?.close();
    _server = null;
    final lockFile = _lockFile;
    _lockFile = null;
    if (lockFile != null) {
      await _deleteLock(lockFile);
    }
  }

  Future<File> _resolveLockFile() async {
    final directory = await _supportDirectory();
    return File("${directory.path}/$_lockFileName");
  }

  Future<void> _listen(File lockFile) async {
    final token = _generateToken();

    ServerSocket server;
    try {
      server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _defaultPort,
      );
    } on SocketException {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    }
    _server = server;

    await _writeLock(lockFile, port: server.port, token: token);
    server.listen((socket) => _handleSocket(socket, token));
  }

  void _handleSocket(Socket socket, String token) {
    // `take(1)` cancels the subscription after the first line, which also
    // finishes this stream. Do not destroy the socket on done: the async
    // handler still has to write the acknowledgement and close it.
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .take(1)
        .listen(
          (line) => unawaited(_handleLine(socket, token, line)),
          onError: (Object _) => socket.destroy(),
        );
  }

  Future<void> _handleLine(Socket socket, String token, String line) async {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        throw const FormatException("Invalid single-instance message");
      }
      final message = SingleInstanceMessage.fromJson(
        decoded.map((key, value) => MapEntry("$key", value)),
      );
      if (message.token != token) {
        throw const FormatException("Invalid single-instance token");
      }
      await _dispatch(message.options);
      socket.write("${jsonEncode({"ok": true})}\n");
      await socket.flush();
      await socket.close();
    } catch (error) {
      try {
        socket.write("${jsonEncode({"ok": false, "error": "$error"})}\n");
        await socket.flush();
      } catch (_) {
        // The peer may already be gone; nothing else to do.
      }
      socket.destroy();
    }
  }

  Future<void> _dispatch(CommandLineOptions options) async {
    if (_disposed) {
      return;
    }
    final handler = _handler;
    if (handler == null) {
      talker.info("Queueing command line options until the UI is ready");
      _pending.add(options);
      return;
    }
    talker.info("Handling command line options from another instance");
    try {
      await handler(options);
    } catch (error, stackTrace) {
      // A bad command must not tear down the listener.
      stderr.writeln("Failed to handle command line options: $error");
      stderr.writeln(stackTrace);
    }
  }

  Future<bool> _forward(_LockInfo info, CommandLineOptions options) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        info.port,
        timeout: _connectTimeout,
      );
      final message = SingleInstanceMessage(
        token: info.token,
        options: options,
      );
      socket.write("${jsonEncode(message.toJson())}\n");
      await socket.flush();

      final response = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(_handshakeTimeout);
      final decoded = jsonDecode(response);
      final ok = decoded is Map && decoded["ok"] == true;
      talker.info("Forwarded command line options: ok=$ok");
      return ok;
    } catch (error) {
      // No live owner for the lock file (stale file, or the owner exited
      // between the read and the connect); the caller takes over.
      talker.info("No running instance accepted the command: $error");
      return false;
    } finally {
      socket?.destroy();
    }
  }

  Future<void> _writeLock(
    File file, {
    required int port,
    required String token,
  }) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({"port": port, "token": token, "pid": pid}),
      flush: true,
    );
  }

  Future<_LockInfo?> _readLock(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return null;
      }
      final port = decoded["port"];
      final token = decoded["token"];
      if (port is! num || token is! String || token.isEmpty) {
        return null;
      }
      return _LockInfo(port: port.toInt(), token: token);
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteLock(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort: a leftover lock file is detected on the next launch.
    }
  }

  static String _generateToken() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, "0"),
    ).join();
  }
}

class _LockInfo {
  const _LockInfo({required this.port, required this.token});

  final int port;
  final String token;
}

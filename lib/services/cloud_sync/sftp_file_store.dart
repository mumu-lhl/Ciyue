import "dart:io";
import "dart:typed_data";

import "package:dartssh2/dartssh2.dart";
import "package:dio/dio.dart" show ProgressCallback;
import "package:path/path.dart" as p;

import "file_store.dart";

/// SFTP implementation that requires an explicitly pinned SHA-256 host-key
/// fingerprint. A missing or mismatched fingerprint is never trusted.
class SftpCloudFileStore implements CloudFileStore {
  final Uri endpoint;
  final String username;
  final String? password;
  final String? privateKey;
  final String? keyPassphrase;
  final String expectedHostKeyFingerprint;

  Future<_SftpConnection>? _connectionFuture;
  int _temporaryFileCounter = 0;

  SftpCloudFileStore({
    required this.endpoint,
    required this.username,
    this.password,
    this.privateKey,
    this.keyPassphrase,
    required this.expectedHostKeyFingerprint,
  }) {
    if (endpoint.scheme != "sftp" || endpoint.host.isEmpty) {
      throw ArgumentError.value(
        endpoint,
        "endpoint",
        "Expected an sftp:// URL.",
      );
    }
    if (endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment) {
      throw ArgumentError.value(
        endpoint,
        "endpoint",
        "SFTP URL must not contain credentials, a query, or a fragment.",
      );
    }
    if (username.isEmpty) throw ArgumentError.value(username, "username");
    if ((password == null || password!.isEmpty) &&
        (privateKey == null || privateKey!.isEmpty)) {
      throw ArgumentError("Provide an SFTP password or private key.");
    }
    if (expectedHostKeyFingerprint.trim().isEmpty) {
      throw ArgumentError("An SSH host-key fingerprint is required.");
    }
    if (endpoint.pathSegments.any(
      (segment) => segment == "." || segment == "..",
    )) {
      throw ArgumentError.value(
        endpoint,
        "endpoint",
        "SFTP base path is invalid.",
      );
    }
  }

  Future<_SftpConnection> _connection() => _connectionFuture ??= _connect();

  Future<_SftpConnection> _connect() async {
    final identities = privateKey == null || privateKey!.isEmpty
        ? null
        : SSHKeyPair.fromPem(privateKey!, keyPassphrase);
    final socket = await SSHSocket.connect(
      endpoint.host,
      endpoint.hasPort ? endpoint.port : 22,
      timeout: const Duration(seconds: 30),
    );
    final client = SSHClient(
      socket,
      username: username,
      identities: identities,
      onPasswordRequest: password == null || password!.isEmpty
          ? null
          : () => password,
      onVerifyHostKey: (type, fingerprint) =>
          String.fromCharCodes(fingerprint) ==
          expectedHostKeyFingerprint.trim(),
      handshakeTimeout: const Duration(seconds: 30),
      authTimeout: const Duration(seconds: 30),
    );
    try {
      final sftp = await client.sftp();
      final requestedBase = endpoint.path.isEmpty ? "." : endpoint.path;
      final basePath = p.posix.normalize(await sftp.absolute(requestedBase));
      if (!p.posix.isAbsolute(basePath)) {
        throw FileSystemException("SFTP base path is not absolute", basePath);
      }
      return _SftpConnection(client: client, sftp: sftp, basePath: basePath);
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  String _cleanRelativePath(String remotePath) {
    if (remotePath.contains("\\") || remotePath.contains("\u0000")) {
      throw ArgumentError.value(remotePath, "remotePath");
    }
    final segments = remotePath.split("/");
    if (segments.any((segment) => segment == "." || segment == "..")) {
      throw ArgumentError.value(remotePath, "remotePath");
    }
    return segments.where((segment) => segment.isNotEmpty).join("/");
  }

  Future<String> _absolutePath(String remotePath) async {
    final path = _cleanRelativePath(remotePath);
    final connection = await _connection();
    return path.isEmpty
        ? connection.basePath
        : p.posix.join(connection.basePath, path);
  }

  @override
  Future<List<CloudFileEntry>> listDirectory(String remotePath) async {
    final path = _cleanRelativePath(remotePath);
    final connection = await _connection();
    final names = await connection.sftp.listdir(await _absolutePath(path));
    final entries = <CloudFileEntry>[];
    for (final item in names) {
      final name = item.filename;
      if (name == "." ||
          name == ".." ||
          name.isEmpty ||
          name.contains("/") ||
          name.contains("\\") ||
          name.contains("\u0000")) {
        continue;
      }
      final type = item.attr.mode?.type;
      // Never follow remote symbolic links from within the sync tree.
      if (type == SftpFileType.symbolicLink) continue;
      final relativePath = path.isEmpty ? name : "$path/$name";
      entries.add(
        CloudFileEntry(
          name: name,
          path: relativePath,
          isDirectory: type == SftpFileType.directory,
          sizeBytes: item.attr.size,
        ),
      );
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  @override
  Future<void> ensureDirectory(String remotePath) async {
    final path = _cleanRelativePath(remotePath);
    if (path.isEmpty) return;
    final connection = await _connection();
    var current = connection.basePath;
    for (final segment in path.split("/")) {
      current = p.posix.join(current, segment);
      try {
        final stat = await connection.sftp.stat(current, followLink: false);
        if (stat.mode?.type != SftpFileType.directory) {
          throw FileSystemException("SFTP path is not a directory", current);
        }
      } on SftpStatusError catch (error) {
        if (error.code != SftpStatusCode.noSuchFile) rethrow;
        try {
          await connection.sftp.mkdir(current);
        } catch (error, stackTrace) {
          // Another device may have created this directory after our stat.
          try {
            final racedStat = await connection.sftp.stat(
              current,
              followLink: false,
            );
            if (racedStat.mode?.type == SftpFileType.directory) continue;
          } on Object {
            // Preserve the original mkdir error if the path still is absent.
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      }
    }
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    File destination, {
    ProgressCallback? onReceiveProgress,
  }) async {
    final path = _cleanRelativePath(remotePath);
    if (path.isEmpty) throw ArgumentError.value(remotePath, "remotePath");
    final connection = await _connection();
    final remotePathOnServer = await _absolutePath(path);
    final stat = await connection.sftp.stat(
      remotePathOnServer,
      followLink: false,
    );
    if (stat.mode?.type != SftpFileType.regularFile) {
      throw FileSystemException("SFTP target is not a regular file", path);
    }

    await destination.parent.create(recursive: true);
    final temporary = File("${destination.path}.ciyue-download");
    if (await temporary.exists()) await temporary.delete();
    try {
      var received = 0;
      final sink = temporary.openWrite();
      try {
        await connection.sftp.download(
          remotePathOnServer,
          sink,
          length: stat.size,
          onProgress: (count) {
            received = count;
            onReceiveProgress?.call(received, stat.size ?? -1);
          },
          closeDestination: true,
        );
      } catch (_) {
        await sink.close();
        rethrow;
      }
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  @override
  Future<void> uploadFile(
    String remotePath,
    File source, {
    ProgressCallback? onSendProgress,
  }) async {
    final path = _cleanRelativePath(remotePath);
    if (path.isEmpty) throw ArgumentError.value(remotePath, "remotePath");
    if (!await source.exists()) {
      throw FileSystemException("Source file not found", source.path);
    }
    final parent = path.contains("/")
        ? path.substring(0, path.lastIndexOf("/"))
        : "";
    if (parent.isNotEmpty) await ensureDirectory(parent);

    final connection = await _connection();
    final target = await _absolutePath(path);
    _temporaryFileCounter++;
    final temporary = p.posix.join(
      p.posix.dirname(target),
      ".ciyue-upload-${DateTime.now().microsecondsSinceEpoch}-$_temporaryFileCounter",
    );
    try {
      final sourceLength = await source.length();
      final remoteFile = await connection.sftp.open(
        temporary,
        mode:
            SftpFileOpenMode.write |
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate,
      );
      try {
        await remoteFile
            .write(
              source.openRead().map((chunk) => Uint8List.fromList(chunk)),
              onProgress: (sent) => onSendProgress?.call(sent, sourceLength),
            )
            .done;
      } finally {
        await remoteFile.close();
      }
      try {
        await connection.sftp.rename(temporary, target);
      } on SftpStatusError {
        // Some servers cannot replace an existing file with rename. Move the
        // old object aside first and restore it if promotion of the new file
        // fails, so an incomplete sync does not discard the prior snapshot.
        final backup = "$temporary.previous";
        var movedPrevious = false;
        try {
          await connection.sftp.rename(target, backup);
          movedPrevious = true;
        } on SftpStatusError catch (error) {
          if (error.code != SftpStatusCode.noSuchFile) rethrow;
        }
        try {
          await connection.sftp.rename(temporary, target);
        } catch (error, stackTrace) {
          if (movedPrevious) {
            try {
              await connection.sftp.rename(backup, target);
            } on Object {
              // Keep the staged previous version if restoration also fails.
            }
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (movedPrevious) {
          try {
            await connection.sftp.remove(backup);
          } on Object {
            // The new target is committed; backup cleanup is best effort.
          }
        }
      }
    } catch (_) {
      try {
        await connection.sftp.remove(temporary);
      } on Object {
        // Best effort cleanup of an interrupted upload.
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    final path = _cleanRelativePath(remotePath);
    if (path.isEmpty) throw ArgumentError.value(remotePath, "remotePath");
    final connection = await _connection();
    await connection.sftp.remove(await _absolutePath(path));
  }

  @override
  Future<void> close() async {
    final future = _connectionFuture;
    if (future == null) return;
    try {
      final connection = await future;
      await connection.sftp.close();
      connection.client.close();
    } catch (_) {
      // A failed initial connection has already been torn down.
    }
  }
}

class _SftpConnection {
  final SSHClient client;
  final SftpClient sftp;
  final String basePath;

  const _SftpConnection({
    required this.client,
    required this.sftp,
    required this.basePath,
  });
}

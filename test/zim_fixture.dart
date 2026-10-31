import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:archive/archive.dart";
import "package:crypto/crypto.dart";

enum ZimCompression {
  none(0),
  zip(2),
  lzma(4),
  zstd(5);

  final int code;
  const ZimCompression(this.code);
}

class _FixtureBlobItem {
  final String namespace;
  final String path;
  final String title;
  final Uint8List data;
  final String mimeType;

  _FixtureBlobItem({
    required this.namespace,
    required this.path,
    required this.title,
    required this.data,
    required this.mimeType,
  });
}

class _FixtureRedirectItem {
  final String namespace;
  final String path;
  final String title;
  final String targetPath;
  final String targetNamespace;

  _FixtureRedirectItem({
    required this.namespace,
    required this.path,
    required this.title,
    required this.targetPath,
    required this.targetNamespace,
  });
}

class ZimFixtureBuilder {
  final List<_FixtureBlobItem> _contentItems = [];
  final List<_FixtureRedirectItem> _redirects = [];
  final Map<String, String> _metadata = {};
  String? mainPagePath;

  void addArticle(
    String path,
    String title,
    String html, {
    String namespace = "A",
  }) {
    _contentItems.add(
      _FixtureBlobItem(
        namespace: namespace,
        path: path,
        title: title,
        data: Uint8List.fromList(utf8.encode(html)),
        mimeType: "text/html",
      ),
    );
  }

  void addResource(
    String path,
    List<int> data,
    String mimeType, {
    String namespace = "I",
    String? title,
  }) {
    _contentItems.add(
      _FixtureBlobItem(
        namespace: namespace,
        path: path,
        title: title ?? path,
        data: Uint8List.fromList(data),
        mimeType: mimeType,
      ),
    );
  }

  void addRedirect(
    String path,
    String title,
    String targetPath, {
    String namespace = "A",
    String targetNamespace = "A",
  }) {
    _redirects.add(
      _FixtureRedirectItem(
        namespace: namespace,
        path: path,
        title: title,
        targetPath: targetPath,
        targetNamespace: targetNamespace,
      ),
    );
  }

  void addMetadata(String key, String value) {
    _metadata[key] = value;
  }

  Future<String> write(
    Directory dir,
    String name, {
    ZimCompression compression = ZimCompression.none,
    bool extendedClusters = false,
    bool includeTitleIndex = true,
    int blobsPerCluster = 10,
    int majorVersion = 6,
    int minorVersion = 0,
  }) async {
    final allContent = List<_FixtureBlobItem>.from(_contentItems);
    for (final entry in _metadata.entries) {
      allContent.add(
        _FixtureBlobItem(
          namespace: "M",
          path: entry.key,
          title: entry.key,
          data: Uint8List.fromList(utf8.encode(entry.value)),
          mimeType: "text/plain",
        ),
      );
    }

    final mimeTypes = <String>[];
    final mimeIndices = <String, int>{};
    for (final item in allContent) {
      if (!mimeIndices.containsKey(item.mimeType)) {
        mimeIndices[item.mimeType] = mimeTypes.length;
        mimeTypes.add(item.mimeType);
      }
    }

    final mimeListBuilder = BytesBuilder();
    for (final mime in mimeTypes) {
      mimeListBuilder.add(utf8.encode(mime));
      mimeListBuilder.addByte(0);
    }
    mimeListBuilder.addByte(0);
    final mimeListBytes = mimeListBuilder.takeBytes();

    final clusters = <Uint8List>[];
    final itemLocations = <(int cluster, int blob)>[];

    for (var i = 0; i < allContent.length; i += blobsPerCluster) {
      final chunk = allContent.skip(i).take(blobsPerCluster).toList();
      final clusterIndex = clusters.length;

      final clusterBuilder = BytesBuilder();
      final totalBlobs = chunk.length;

      if (!extendedClusters) {
        final offsetTableSize = (totalBlobs + 1) * 4;
        final offsets = <int>[offsetTableSize];
        var currentOffset = offsetTableSize;
        for (final blob in chunk) {
          currentOffset += blob.data.length;
          offsets.add(currentOffset);
        }

        final bd = ByteData(offsets.length * 4);
        for (var b = 0; b < offsets.length; b++) {
          bd.setUint32(b * 4, offsets[b], Endian.little);
        }
        clusterBuilder.add(bd.buffer.asUint8List());
        for (final blob in chunk) {
          clusterBuilder.add(blob.data);
        }
      } else {
        final offsetTableSize = (totalBlobs + 1) * 8;
        final offsets = <int>[offsetTableSize];
        var currentOffset = offsetTableSize;
        for (final blob in chunk) {
          currentOffset += blob.data.length;
          offsets.add(currentOffset);
        }

        final bd = ByteData(offsets.length * 8);
        for (var b = 0; b < offsets.length; b++) {
          bd.setUint64(b * 8, offsets[b], Endian.little);
        }
        clusterBuilder.add(bd.buffer.asUint8List());
        for (final blob in chunk) {
          clusterBuilder.add(blob.data);
        }
      }

      final uncompressedCluster = clusterBuilder.takeBytes();

      final infoByte =
          (extendedClusters ? 0x10 : 0x00) | (compression.code & 0x0f);
      Uint8List compressedPayload;
      switch (compression) {
        case ZimCompression.none:
          compressedPayload = uncompressedCluster;
          break;
        case ZimCompression.zip:
          compressedPayload = Uint8List.fromList(
            zlib.encode(uncompressedCluster),
          );
          break;
        case ZimCompression.lzma:
          compressedPayload = XZEncoder().encodeBytes(uncompressedCluster);
          break;
        case ZimCompression.zstd:
          compressedPayload = ZstdEncoder().encodeBytes(uncompressedCluster);
          break;
      }

      final fullCluster = BytesBuilder();
      fullCluster.addByte(infoByte);
      fullCluster.add(compressedPayload);
      clusters.add(fullCluster.takeBytes());

      for (var b = 0; b < chunk.length; b++) {
        itemLocations.add((clusterIndex, b));
      }
    }

    final rawEntries = <_RawEntry>[];
    for (var i = 0; i < allContent.length; i++) {
      final item = allContent[i];
      final (cluster, blob) = itemLocations[i];
      rawEntries.add(
        _RawEntry(
          namespace: item.namespace,
          path: item.path,
          title: item.title,
          mimeTypeIndex: mimeIndices[item.mimeType]!,
          clusterNumber: cluster,
          blobNumber: blob,
        ),
      );
    }

    for (final redir in _redirects) {
      rawEntries.add(
        _RawEntry(
          namespace: redir.namespace,
          path: redir.path,
          title: redir.title,
          mimeTypeIndex: 0xffff,
          targetPath: redir.targetPath,
          targetNamespace: redir.targetNamespace,
        ),
      );
    }

    rawEntries.sort((a, b) {
      final nsCmp = a.namespace.compareTo(b.namespace);
      if (nsCmp != 0) return nsCmp;
      return a.path.compareTo(b.path);
    });

    for (final entry in rawEntries) {
      if (entry.isRedirect) {
        final targetIdx = rawEntries.indexWhere(
          (e) =>
              e.namespace == entry.targetNamespace &&
              e.path == entry.targetPath,
        );
        if (targetIdx < 0) {
          throw StateError(
            "Redirect target not found: ${entry.targetNamespace}/${entry.targetPath}",
          );
        }
        entry.redirectIndex = targetIdx;
      }
    }

    int mainPage = 0xffffffff;
    if (mainPagePath != null) {
      final mpIdx = rawEntries.indexWhere((e) => e.path == mainPagePath);
      if (mpIdx >= 0) mainPage = mpIdx;
    }

    final encodedEntries = <Uint8List>[];
    for (final entry in rawEntries) {
      final eb = BytesBuilder();
      final bd = ByteData(entry.isRedirect ? 12 : 16);
      bd.setUint16(0, entry.mimeTypeIndex, Endian.little);
      bd.setUint8(2, 0);
      bd.setUint8(3, entry.namespace.codeUnitAt(0));
      bd.setUint32(4, 0, Endian.little);
      if (entry.isRedirect) {
        bd.setUint32(8, entry.redirectIndex!, Endian.little);
      } else {
        bd.setUint32(8, entry.clusterNumber, Endian.little);
        bd.setUint32(12, entry.blobNumber, Endian.little);
      }
      eb.add(bd.buffer.asUint8List());

      eb.add(utf8.encode(entry.path));
      eb.addByte(0);

      if (entry.title == entry.path || entry.title.isEmpty) {
        eb.addByte(0);
      } else {
        eb.add(utf8.encode(entry.title));
        eb.addByte(0);
      }

      encodedEntries.add(eb.takeBytes());
    }

    const headerSize = 80;
    final mimeListPos = headerSize;
    final direntsPos = mimeListPos + mimeListBytes.length;

    var currentOffset = direntsPos;
    final entryFileOffsets = <int>[];
    for (final ee in encodedEntries) {
      entryFileOffsets.add(currentOffset);
      currentOffset += ee.length;
    }

    final pathPtrPos = currentOffset;
    currentOffset += rawEntries.length * 8;

    final titlePtrPos = includeTitleIndex ? currentOffset : 0;
    if (includeTitleIndex) {
      currentOffset += rawEntries.length * 4;
    }

    final clusterPtrPos = currentOffset;
    currentOffset += clusters.length * 8;

    final clusterFileOffsets = <int>[];
    for (final c in clusters) {
      clusterFileOffsets.add(currentOffset);
      currentOffset += c.length;
    }

    final checksumPos = currentOffset;

    final headerBd = ByteData(headerSize);
    headerBd.setUint32(0, 0x044D495A, Endian.little);
    headerBd.setUint16(4, majorVersion, Endian.little);
    headerBd.setUint16(6, minorVersion, Endian.little);
    for (var u = 0; u < 16; u++) {
      headerBd.setUint8(8 + u, u + 1);
    }
    headerBd.setUint32(24, rawEntries.length, Endian.little);
    headerBd.setUint32(28, clusters.length, Endian.little);
    headerBd.setUint64(32, pathPtrPos, Endian.little);
    headerBd.setUint64(40, titlePtrPos, Endian.little);
    headerBd.setUint64(48, clusterPtrPos, Endian.little);
    headerBd.setUint64(56, mimeListPos, Endian.little);
    headerBd.setUint32(64, mainPage, Endian.little);
    headerBd.setUint32(68, 0xffffffff, Endian.little);
    headerBd.setUint64(72, checksumPos, Endian.little);

    final pathPtrBd = ByteData(rawEntries.length * 8);
    for (var i = 0; i < rawEntries.length; i++) {
      pathPtrBd.setUint64(i * 8, entryFileOffsets[i], Endian.little);
    }

    ByteData? titlePtrBd;
    if (includeTitleIndex) {
      final titleOrder = List<int>.generate(rawEntries.length, (i) => i)
        ..sort((a, b) {
          final ea = rawEntries[a];
          final eb = rawEntries[b];
          final nsCmp = ea.namespace.compareTo(eb.namespace);
          if (nsCmp != 0) return nsCmp;
          return ea.title.compareTo(eb.title);
        });

      titlePtrBd = ByteData(rawEntries.length * 4);
      for (var i = 0; i < titleOrder.length; i++) {
        titlePtrBd.setUint32(i * 4, titleOrder[i], Endian.little);
      }
    }

    final clusterPtrBd = ByteData(clusters.length * 8);
    for (var i = 0; i < clusters.length; i++) {
      clusterPtrBd.setUint64(i * 8, clusterFileOffsets[i], Endian.little);
    }

    final fileBuilder = BytesBuilder();
    fileBuilder.add(headerBd.buffer.asUint8List());
    fileBuilder.add(mimeListBytes);
    for (final ee in encodedEntries) {
      fileBuilder.add(ee);
    }
    fileBuilder.add(pathPtrBd.buffer.asUint8List());
    if (titlePtrBd != null) {
      fileBuilder.add(titlePtrBd.buffer.asUint8List());
    }
    fileBuilder.add(clusterPtrBd.buffer.asUint8List());
    for (final c in clusters) {
      fileBuilder.add(c);
    }

    final payloadSoFar = fileBuilder.takeBytes();
    assert(payloadSoFar.length == checksumPos);

    final digest = md5.convert(payloadSoFar);
    assert(digest.bytes.length == 16);

    final finalFile = BytesBuilder();
    finalFile.add(payloadSoFar);
    finalFile.add(digest.bytes);

    final filePath = "${dir.path}/$name.zim";
    await File(filePath).writeAsBytes(finalFile.takeBytes());
    return filePath;
  }
}

class _RawEntry {
  final String namespace;
  final String path;
  final String title;
  final int mimeTypeIndex;
  final int clusterNumber;
  final int blobNumber;
  final String? targetPath;
  final String? targetNamespace;
  int? redirectIndex;

  bool get isRedirect => mimeTypeIndex == 0xffff;

  _RawEntry({
    required this.namespace,
    required this.path,
    required this.title,
    required this.mimeTypeIndex,
    this.clusterNumber = 0,
    this.blobNumber = 0,
    this.targetPath,
    this.targetNamespace,
  });
}

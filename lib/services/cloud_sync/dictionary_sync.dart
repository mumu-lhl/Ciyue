import "dart:convert";
import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/cloud_sync/coordinator.dart";
import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:crypto/crypto.dart";
import "package:path/path.dart" as p;

class DictionarySyncItem {
  final String packageId;
  final String title;
  final String fileName;
  final int fileCount;
  final int totalSizeBytes;
  final bool availableLocally;
  final bool availableRemotely;

  const DictionarySyncItem({
    required this.packageId,
    required this.title,
    required this.fileName,
    required this.fileCount,
    required this.totalSizeBytes,
    required this.availableLocally,
    required this.availableRemotely,
  });
}

class DictionarySyncPreview {
  final String remoteRoot;
  final List<DictionarySyncItem> items;
  final Map<String, _DictionaryPackage> _localPackages;
  final Map<String, _DictionaryPackage> _remotePackages;

  factory DictionarySyncPreview.forDisplay(List<DictionarySyncItem> items) =>
      DictionarySyncPreview._(
        remoteRoot: "",
        items: items,
        localPackages: const {},
        remotePackages: const {},
      );

  DictionarySyncPreview._({
    required this.remoteRoot,
    required List<DictionarySyncItem> items,
    required Map<String, _DictionaryPackage> localPackages,
    required Map<String, _DictionaryPackage> remotePackages,
  }) : items = List.unmodifiable(items),
       _localPackages = Map.unmodifiable(localPackages),
       _remotePackages = Map.unmodifiable(remotePackages);
}

/// Previews and transfers user-selected dictionary packages.
///
/// A package includes its MDX file, adjacent MDD resources, CSS/JS sidecars,
/// and the custom font configured for that dictionary. Previewing only reads
/// local files and remote metadata; it does not create or upload cloud files.
class DictionarySyncService {
  final AppDatabase database;

  const DictionarySyncService({required this.database});

  Future<DictionarySyncPreview> preview({
    required CloudFileStore fileStore,
    required String remoteRoot,
    required bool remoteFolderExists,
  }) async {
    final localPackages = await _readLocalPackages();
    final remotePackages = <String, _DictionaryPackage>{};

    // A missing remote root remains a read-only empty result during preview.
    if (remoteFolderExists) {
      remotePackages.addAll(await _readRemotePackages(fileStore, remoteRoot));
    }

    final packageIds = {...localPackages.keys, ...remotePackages.keys}.toList()
      ..sort();
    final items = <DictionarySyncItem>[];
    for (final packageId in packageIds) {
      final local = localPackages[packageId];
      final remote = remotePackages[packageId];
      final package = local ?? remote!;
      items.add(
        DictionarySyncItem(
          packageId: packageId,
          title: package.title,
          fileName: package.files
              .singleWhere((file) => file.role == "mdx")
              .remoteName,
          fileCount: package.files.length,
          totalSizeBytes: package.totalSizeBytes,
          availableLocally: local != null,
          availableRemotely: remote != null,
        ),
      );
    }

    items.sort((a, b) {
      final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (byTitle != 0) return byTitle;
      final byFileName = a.fileName.toLowerCase().compareTo(
        b.fileName.toLowerCase(),
      );
      return byFileName != 0 ? byFileName : a.packageId.compareTo(b.packageId);
    });
    return DictionarySyncPreview._(
      remoteRoot: normalizeCloudSyncRemoteRoot(remoteRoot),
      items: items,
      localPackages: localPackages,
      remotePackages: remotePackages,
    );
  }

  Future<Map<String, _DictionaryPackage>> _readLocalPackages() async {
    final packages = <String, _DictionaryPackage>{};
    final dictionaries = await database.dictionaryListDao.all();
    for (final dictionary in dictionaries) {
      final package = await _readLocalPackage(dictionary);
      if (package != null) {
        packages.putIfAbsent(package.packageId, () => package);
      }
    }
    return packages;
  }

  Future<_DictionaryPackage?> _readLocalPackage(
    DictionaryListData dictionary,
  ) async {
    final basePath = dictionary.path;
    final mdxFile = File("$basePath.mdx");
    if (!await mdxFile.exists()) return null;

    final files = <_DictionaryPackageFile>[
      await _captureFile(mdxFile, role: "mdx"),
    ];
    final baseName = p.basename(basePath);
    final directory = p.dirname(basePath);
    final mdd = File("$basePath.mdd");
    if (await mdd.exists()) {
      files.add(await _captureFile(mdd, role: "mdd"));
    }
    for (var part = 1; ; part++) {
      final resource = File("$basePath.$part.mdd");
      if (!await resource.exists()) break;
      files.add(await _captureFile(resource, role: "mdd"));
    }

    for (final extension in const ["css", "js"]) {
      final sidecar = File(p.join(directory, "$baseName.$extension"));
      if (await sidecar.exists()) {
        files.add(await _captureFile(sidecar, role: extension));
      }
    }

    final fontPath = dictionary.fontPath;
    if (fontPath != null) {
      final font = File(fontPath);
      if (await font.exists()) {
        files.add(await _captureFile(font, role: "font"));
      }
    }

    files.sort((a, b) => a.remoteName.compareTo(b.remoteName));
    final packageId = _packageId(files);
    return _DictionaryPackage(
      packageId: packageId,
      title: dictionary.title?.trim().isNotEmpty == true
          ? dictionary.title!.trim()
          : baseName,
      files: List.unmodifiable(files),
    );
  }

  Future<_DictionaryPackageFile> _captureFile(
    File file, {
    required String role,
  }) async {
    final name = p.basename(file.path);
    final remoteName = role == "font" ? "font/$name" : name;
    if (!_validRemoteName(role, remoteName)) {
      throw FormatException("Unsupported dictionary file name: '$name'.");
    }
    return _DictionaryPackageFile(
      role: role,
      remoteName: remoteName,
      source: file,
      sizeBytes: await file.length(),
      sha256: (await sha256.bind(file.openRead()).first).toString(),
    );
  }

  Future<void> transferSelected({
    required CloudFileStore fileStore,
    required String remoteRoot,
    required DictionarySyncPreview preview,
    required Set<String> selectedPackageIds,
    required Directory dictionaryStorageDirectory,
  }) async {
    final normalizedRoot = normalizeCloudSyncRemoteRoot(remoteRoot);
    if (preview.remoteRoot != normalizedRoot) {
      throw StateError(
        "Dictionary preview belongs to a different cloud folder.",
      );
    }
    final knownIds = preview.items.map((item) => item.packageId).toSet();
    final unknownIds = selectedPackageIds.difference(knownIds);
    if (unknownIds.isNotEmpty) {
      throw ArgumentError.value(unknownIds, "selectedPackageIds");
    }

    final packagesToUpload = <_DictionaryPackage>[];
    for (final packageId in selectedPackageIds) {
      final local = preview._localPackages[packageId];
      final remote = preview._remotePackages[packageId];
      if (local != null && remote == null) {
        await _verifyUnchanged(local);
        packagesToUpload.add(local);
      }
    }

    final packagesRoot = p.posix.join(
      normalizedRoot,
      "dictionaries",
      "packages",
    );
    for (final package in packagesToUpload) {
      await _uploadPackage(fileStore, packagesRoot, package);
    }

    for (final packageId in selectedPackageIds) {
      final remote = preview._remotePackages[packageId];
      if (remote != null && preview._localPackages[packageId] == null) {
        await _downloadPackage(
          fileStore,
          p.posix.join(packagesRoot, packageId),
          remote,
          dictionaryStorageDirectory,
        );
      }
    }
  }

  Future<void> _uploadPackage(
    CloudFileStore fileStore,
    String packagesRoot,
    _DictionaryPackage package,
  ) async {
    final packageRoot = p.posix.join(packagesRoot, package.packageId);
    await fileStore.ensureDirectory(packageRoot);
    for (final file in package.files) {
      final source = file.source;
      if (source == null) {
        throw StateError("Dictionary package is missing a local file.");
      }
      final remoteFilePath = p.posix.join(packageRoot, file.remoteName);
      final remoteParent = p.posix.dirname(remoteFilePath);
      if (remoteParent != packageRoot) {
        await fileStore.ensureDirectory(remoteParent);
      }
      await fileStore.uploadFile(remoteFilePath, source);
    }

    final temporaryDirectory = await Directory.systemTemp.createTemp(
      "ciyue-dictionary-manifest-",
    );
    try {
      final manifest = File(p.join(temporaryDirectory.path, "manifest.json"));
      await manifest.writeAsString(jsonEncode(package.toJson()), flush: true);
      await fileStore.uploadFile(
        p.posix.join(packageRoot, "manifest.json"),
        manifest,
      );
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  }

  Future<void> _verifyUnchanged(_DictionaryPackage package) async {
    for (final file in package.files) {
      final source = file.source;
      if (source == null || !await source.exists()) {
        throw StateError("A selected dictionary file is no longer available.");
      }
      if (await source.length() != file.sizeBytes ||
          (await sha256.bind(source.openRead()).first).toString() !=
              file.sha256) {
        throw StateError(
          "A selected dictionary changed after preview; preview it again.",
        );
      }
    }
  }

  Future<Map<String, _DictionaryPackage>> _readRemotePackages(
    CloudFileStore fileStore,
    String remoteRoot,
  ) async {
    final root = normalizeCloudSyncRemoteRoot(remoteRoot);
    final rootEntries = await fileStore.listDirectory(root);
    final dictionariesDirectory = _findDirectory(rootEntries, "dictionaries");
    if (dictionariesDirectory == null) return const {};

    final dictionaryEntries = await fileStore.listDirectory(
      dictionariesDirectory.path,
    );
    final packagesDirectory = _findDirectory(dictionaryEntries, "packages");
    if (packagesDirectory == null) return const {};

    final packageEntries = await fileStore.listDirectory(
      packagesDirectory.path,
    );
    final packages = <String, _DictionaryPackage>{};
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      "ciyue-dictionary-preview-",
    );
    try {
      for (final entry in packageEntries) {
        if (!entry.isDirectory || !_isPackageId(entry.name)) continue;
        final packageRoot = p.posix.join(packagesDirectory.path, entry.name);
        final files = await fileStore.listDirectory(packageRoot);
        final manifest = files
            .where((file) => !file.isDirectory && file.name == "manifest.json")
            .firstOrNull;
        if (manifest == null) continue;
        if (manifest.sizeBytes != null && manifest.sizeBytes! > 1024 * 1024) {
          throw const FormatException("Dictionary manifest is too large.");
        }
        final localManifest = File(
          p.join(temporaryDirectory.path, "${entry.name}.json"),
        );
        await fileStore.downloadFile(
          p.posix.join(packageRoot, "manifest.json"),
          localManifest,
        );
        if (await localManifest.length() > 1024 * 1024) {
          throw const FormatException("Dictionary manifest is too large.");
        }
        final package = _DictionaryPackage.fromJson(
          jsonDecode(await localManifest.readAsString()),
          expectedPackageId: entry.name,
        );
        packages[package.packageId] = package;
      }
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
    return packages;
  }

  Future<void> _downloadPackage(
    CloudFileStore fileStore,
    String packageRoot,
    _DictionaryPackage package,
    Directory dictionaryStorageDirectory,
  ) async {
    await dictionaryStorageDirectory.create(recursive: true);
    final destination = Directory(
      p.join(dictionaryStorageDirectory.path, package.packageId),
    );
    if (await destination.exists()) {
      await _verifyDownloadedPackage(destination, package);
      await _registerPackage(destination, package);
      return;
    }

    final staging = Directory(
      p.join(dictionaryStorageDirectory.path, ".${package.packageId}.partial"),
    );
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create();
    try {
      for (final file in package.files) {
        final localFile = File(
          p.joinAll([staging.path, ...file.remoteName.split("/")]),
        );
        await localFile.parent.create(recursive: true);
        await fileStore.downloadFile(
          p.posix.join(packageRoot, file.remoteName),
          localFile,
        );
        await _verifyFile(localFile, file);
      }
      await staging.rename(destination.path);
    } catch (_) {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      rethrow;
    }
    await _registerPackage(destination, package);
  }

  Future<void> _verifyDownloadedPackage(
    Directory directory,
    _DictionaryPackage package,
  ) async {
    for (final file in package.files) {
      final localFile = File(
        p.joinAll([directory.path, ...file.remoteName.split("/")]),
      );
      await _verifyFile(localFile, file);
    }
  }

  Future<void> _verifyFile(File localFile, _DictionaryPackageFile file) async {
    if (!await localFile.exists() ||
        await localFile.length() != file.sizeBytes) {
      throw FormatException(
        "A downloaded dictionary file has an invalid size.",
      );
    }
    final actualHash = (await sha256.bind(localFile.openRead()).first)
        .toString();
    if (actualHash != file.sha256) {
      throw FormatException(
        "A downloaded dictionary file failed checksum verification.",
      );
    }
  }

  Future<void> _registerPackage(
    Directory directory,
    _DictionaryPackage package,
  ) async {
    final mdx = package.files.singleWhere((file) => file.role == "mdx");
    final mdxName = mdx.remoteName;
    final baseName = p.withoutExtension(p.basename(mdxName));
    final basePath = p.join(directory.path, baseName);
    if (await database.dictionaryListDao.dictionaryExist(basePath)) return;

    final dictionaryId = await database.dictionaryListDao.add(
      basePath,
      package.title,
    );
    final font = package.files.where((file) => file.role == "font").firstOrNull;
    if (font != null) {
      await database.dictionaryListDao.updateFont(
        dictionaryId,
        p.joinAll([directory.path, ...font.remoteName.split("/")]),
      );
    }
  }
}

class _DictionaryPackage {
  final String packageId;
  final String title;
  final List<_DictionaryPackageFile> files;

  const _DictionaryPackage({
    required this.packageId,
    required this.title,
    required this.files,
  });

  int get totalSizeBytes =>
      files.fold(0, (total, file) => total + file.sizeBytes);

  Map<String, Object?> toJson() => {
    "app": "ciyue",
    "formatVersion": 1,
    "packageId": packageId,
    "title": title,
    "files": [
      for (final file in files)
        {
          "role": file.role,
          "name": file.remoteName,
          "sizeBytes": file.sizeBytes,
          "sha256": file.sha256,
        },
    ],
  };

  factory _DictionaryPackage.fromJson(
    Object? value, {
    required String expectedPackageId,
  }) {
    if (value is! Map ||
        value["app"] != "ciyue" ||
        value["formatVersion"] != 1 ||
        value["packageId"] != expectedPackageId ||
        value["title"] is! String ||
        (value["title"] as String).trim().isEmpty ||
        value["files"] is! List) {
      throw const FormatException("Invalid Ciyue dictionary manifest.");
    }

    final files = <_DictionaryPackageFile>[];
    final seenNames = <String>{};
    for (final item in value["files"] as List) {
      if (item is! Map ||
          item["role"] is! String ||
          item["name"] is! String ||
          item["sizeBytes"] is! int ||
          item["sha256"] is! String) {
        throw const FormatException("Invalid Ciyue dictionary file entry.");
      }
      final role = item["role"] as String;
      final name = item["name"] as String;
      final sizeBytes = item["sizeBytes"] as int;
      final hash = item["sha256"] as String;
      if (!_validRemoteName(role, name) ||
          !seenNames.add(name) ||
          sizeBytes < 0 ||
          !RegExp(r"^[a-f0-9]{64}$").hasMatch(hash)) {
        throw const FormatException("Unsafe Ciyue dictionary file entry.");
      }
      files.add(
        _DictionaryPackageFile(
          role: role,
          remoteName: name,
          source: null,
          sizeBytes: sizeBytes,
          sha256: hash,
        ),
      );
    }

    if (files.isEmpty ||
        files.where((file) => file.role == "mdx").length != 1 ||
        files.where((file) => file.role == "font").length > 1 ||
        files.where((file) => file.role == "css").length > 1 ||
        files.where((file) => file.role == "js").length > 1 ||
        files.length > 1000) {
      throw const FormatException("Invalid dictionary package file set.");
    }
    final mdxName = files.singleWhere((file) => file.role == "mdx").remoteName;
    final mdxStem = p.withoutExtension(mdxName);
    for (final file in files) {
      final validAssociation = switch (file.role) {
        "mdx" => true,
        "mdd" =>
          file.remoteName == "$mdxStem.mdd" ||
              RegExp("^${RegExp.escape(mdxStem)}\\.[1-9][0-9]*\\.mdd\$")
                  .hasMatch(file.remoteName),
        "css" => file.remoteName == "$mdxStem.css",
        "js" => file.remoteName == "$mdxStem.js",
        "font" => true,
        _ => false,
      };
      if (!validAssociation) {
        throw const FormatException(
          "Dictionary resource does not match its MDX file.",
        );
      }
    }
    files.sort((a, b) => a.remoteName.compareTo(b.remoteName));
    if (!_isPackageId(expectedPackageId) ||
        _packageId(files) != expectedPackageId) {
      throw const FormatException(
        "Dictionary package checksum does not match.",
      );
    }
    return _DictionaryPackage(
      packageId: expectedPackageId,
      title: (value["title"] as String).trim(),
      files: List.unmodifiable(files),
    );
  }
}

class _DictionaryPackageFile {
  final String role;
  final String remoteName;
  final File? source;
  final int sizeBytes;
  final String sha256;

  const _DictionaryPackageFile({
    required this.role,
    required this.remoteName,
    required this.source,
    required this.sizeBytes,
    required this.sha256,
  });
}

String _packageId(List<_DictionaryPackageFile> files) {
  final sortedFiles = files.toList()
    ..sort((a, b) => a.remoteName.compareTo(b.remoteName));
  final content = jsonEncode([
    for (final file in sortedFiles)
      {
        "name": file.remoteName,
        "role": file.role,
        "sizeBytes": file.sizeBytes,
        "sha256": file.sha256,
      },
  ]);
  return sha256.convert(utf8.encode(content)).toString();
}

CloudFileEntry? _findDirectory(List<CloudFileEntry> entries, String name) =>
    entries
        .where((entry) => entry.isDirectory && entry.name == name)
        .firstOrNull;

bool _isPackageId(String value) => RegExp(r"^[a-f0-9]{64}$").hasMatch(value);

bool _validRemoteName(String role, String name) {
  const fileRoles = {"mdx", "mdd", "css", "js"};
  if (role == "font") {
    if (!name.startsWith("font/")) return false;
    name = name.substring("font/".length);
  } else if (!fileRoles.contains(role)) {
    return false;
  }
  if (name.isEmpty ||
      name == "." ||
      name == ".." ||
      name.contains("/") ||
      name.contains("\\") ||
      name.contains(":") ||
      name.contains("\u0000") ||
      name.toLowerCase().contains("%2f")) {
    return false;
  }
  return switch (role) {
    "mdx" => name.endsWith(".mdx"),
    "mdd" => name.endsWith(".mdd"),
    "css" => name.endsWith(".css"),
    "js" => name.endsWith(".js"),
    "font" => true,
    _ => false,
  };
}

import "dart:convert";
import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/dictionary_lookup.dart";
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
/// A package is everything one dictionary needs to open again, in either
/// format: an MDX file with its adjacent MDD resources and CSS/JS sidecars, or
/// a StarDict one with its `.ifo`, its `.idx` and `.dict` in whichever
/// spelling they take, its `.syn`, and a resource archive in any of the three
/// places the reader looks (`res.zip`, `<name>.res.zip`, `res/res.zip`). A
/// `res/` folder travels as well, but only while it stays small (see
/// [maxResourceDirectoryFiles]) — a pack with thousands of loose resources
/// belongs in an archive. The custom font configured for the dictionary
/// travels with both. Previewing only reads local files and remote metadata;
/// it does not create or upload cloud files.
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
          fileName: package.entryFile.remoteName,
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
    return DictionaryType.isStardict(dictionary.type)
        ? _readLocalStardictPackage(dictionary)
        : _readLocalMdxPackage(dictionary);
  }

  Future<_DictionaryPackage?> _readLocalMdxPackage(
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

    return _finishPackage(dictionary, files, baseName);
  }

  /// A StarDict dictionary is several files sharing one base name, and the
  /// index and the body each come in a plain and a compressed spelling.
  Future<_DictionaryPackage?> _readLocalStardictPackage(
    DictionaryListData dictionary,
  ) async {
    final basePath = dictionary.path;
    final ifo = await _firstExisting(basePath, const [".ifo"]);
    final idx = await _firstExisting(basePath, const [".idx", ".idx.gz"]);
    final body = await _firstExisting(basePath, const [".dict", ".dict.dz"]);
    // Without all three nothing a restore wrote could be opened, so this is
    // not a package worth offering rather than a broken one to upload.
    if (ifo == null || idx == null || body == null) return null;

    final files = <_DictionaryPackageFile>[
      await _captureFile(ifo, role: "ifo"),
      await _captureFile(idx, role: "idx"),
      await _captureFile(body, role: "dict"),
    ];
    // The synonym index has three spellings in the wild: plain, gzipped, and
    // dictzipped. PyGlossary emits the last one when asked to compress it, and
    // the reader only opens the first two — a `.syn.dz` is inert today, but it
    // is still the pack's own file and is not dropped here.
    final syn = await _firstExisting(basePath, const [
      ".syn",
      ".syn.gz",
      ".syn.dz",
    ]);
    if (syn != null) {
      files.add(await _captureFile(syn, role: "syn"));
    }
    // Entry resources live in a `res/` folder or in an archive. The reader
    // looks for `res.zip`, then `<name>.res.zip`, then `res/res.zip`, all of
    // them beside the dictionary, so every archive that exists is captured —
    // whichever spelling the pack happened to use keeps working after a
    // restore.
    final directory = p.dirname(basePath);
    final base = p.basename(basePath);
    for (final (remoteName, archivePath) in [
      ("res.zip", p.join(directory, "res.zip")),
      ("$base.res.zip", p.join(directory, "$base.res.zip")),
      ("res/res.zip", p.join(directory, "res", "res.zip")),
    ]) {
      final archive = File(archivePath);
      if (await archive.exists()) {
        files.add(
          await _captureFile(archive, role: "res", remoteName: remoteName),
        );
      }
    }

    // Files under `res/` travel only while the folder stays small; see
    // [maxResourceDirectoryFiles]. The `res/res.zip` copy is already in the
    // package as an archive, so the one inside the folder is skipped.
    for (final file in await _resourceDirectoryFiles(directory)) {
      final remoteName = p
          .split(p.relative(file.path, from: directory))
          .join("/");
      if (remoteName == "res/res.zip") continue;
      files.add(
        await _captureFile(file, role: "resdir", remoteName: remoteName),
      );
    }

    return _finishPackage(dictionary, files, p.basename(basePath));
  }

  /// Files under `res/`, or nothing when the folder is too large to carry.
  ///
  /// All or nothing on purpose: half a resource folder is worse than none,
  /// because the entry HTML would then reference images that were left behind.
  Future<List<File>> _resourceDirectoryFiles(String directory) async {
    final resDirectory = Directory(p.join(directory, "res"));
    if (!await resDirectory.exists()) return const [];
    final files = <File>[];
    var bytes = 0;
    await for (final entity in resDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      files.add(entity);
      bytes += await entity.length();
      if (files.length > maxResourceDirectoryFiles ||
          bytes > _maxResourceDirectoryBytes) {
        return const [];
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<_DictionaryPackage> _finishPackage(
    DictionaryListData dictionary,
    List<_DictionaryPackageFile> files,
    String baseName,
  ) async {
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
    String? remoteName,
  }) async {
    final name = p.basename(file.path);
    final resolvedName = remoteName ?? (role == "font" ? "font/$name" : name);
    if (!_validRemoteName(role, resolvedName)) {
      throw FormatException("Unsupported dictionary file name: '$name'.");
    }
    return _DictionaryPackageFile(
      role: role,
      remoteName: resolvedName,
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
    final entry = package.entryFile;
    final isMdx = entry.role == "mdx";
    final baseName = isMdx
        ? p.withoutExtension(p.basename(entry.remoteName))
        : _stardictStem(p.basename(entry.remoteName));
    final basePath = p.join(directory.path, baseName);
    if (await database.dictionaryListDao.dictionaryExist(basePath)) return;

    final dictionaryId = await database.dictionaryListDao.add(
      basePath,
      package.title,
      // A restored StarDict row has to say so, or the settings and the lookup
      // read it as an MDX dictionary and look for files it does not have.
      type: isMdx ? 1 : DictionaryType.stardict,
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

  /// The file that identifies the dictionary to a reader: the MDX, or the
  /// StarDict `.ifo`. [_validateFileSet] admits exactly one of the two.
  _DictionaryPackageFile get entryFile =>
      files.firstWhere((file) => file.role == "mdx" || file.role == "ifo");

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

    _validateFileSet(files);
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
  if (role == "resdir") {
    // Files under `res/` keep their path, which may have subdirectories, so
    // this is the one role whose name may contain `/` — as long as it cannot
    // climb out of the folder.
    if (!name.startsWith("res/")) return false;
    return _validRelativePath(name.substring("res/".length));
  }
  const fileRoles = {
    "mdx",
    "mdd",
    "css",
    "js",
    "ifo",
    "idx",
    "dict",
    "syn",
    "res",
  };
  if (role == "font") {
    if (!name.startsWith("font/")) return false;
    name = name.substring("font/".length);
  } else if (role == "res") {
    // A resource archive sits either beside the dictionary or inside its
    // `res/` folder; the second is the only shape that names a directory, and
    // it is a single fixed path rather than an arbitrary subpath.
    if (name == "res/res.zip") return true;
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
    "ifo" => name.endsWith(".ifo"),
    "idx" => name.endsWith(".idx") || name.endsWith(".idx.gz"),
    "dict" => name.endsWith(".dict") || name.endsWith(".dict.dz"),
    "syn" =>
      name.endsWith(".syn") ||
          name.endsWith(".syn.gz") ||
          name.endsWith(".syn.dz"),
    "res" => name == "res.zip" || name.endsWith(".res.zip"),
    "font" => true,
    _ => false,
  };
}

/// The role names that only a StarDict package carries.
const _stardictRoles = {"ifo", "idx", "dict", "syn", "res", "resdir"};

/// Most files carried from a dictionary's `res/` folder.
///
/// Resources in a folder are ordinary files, so each one costs its own cloud
/// request. Keeping the folder only while it is small lets a stray stylesheet
/// travel with the package, while a pack holding thousands of audio files is
/// left to its archive instead of pushing the package past its file-count
/// limit.
const maxResourceDirectoryFiles = 100;

/// Most bytes carried from a dictionary's `res/` folder.
const _maxResourceDirectoryBytes = 20 * 1024 * 1024;

/// The base name the files of one StarDict dictionary share: `sample.dict.dz`
/// and `sample.idx.gz` both answer `sample`. [p.withoutExtension] cannot do
/// this, as it only strips the last suffix.
String _stardictStem(String name) {
  for (final suffix in const [
    ".ifo",
    ".idx.gz",
    ".idx",
    ".dict.dz",
    ".dict",
    ".syn.gz",
    ".syn.dz",
    ".syn",
  ]) {
    if (name.endsWith(suffix)) {
      return name.substring(0, name.length - suffix.length);
    }
  }
  return name;
}

/// Whether [name] is one of the three places the reader looks for a resource
/// archive belonging to the dictionary whose base name is [stem].
bool _isResourceArchive(String name, String stem) =>
    name == "res.zip" || name == "res/res.zip" || name == "$stem.res.zip";

/// Whether [path], a `/`-separated relative path, stays inside the folder it
/// is joined to: no empty, `.` or `..` segment, no absolute root, and no
/// separator or drive letter other than `/`.
bool _validRelativePath(String path) {
  if (path.isEmpty ||
      path.startsWith("/") ||
      path.contains("\\") ||
      path.contains(":") ||
      path.contains("\u0000") ||
      path.toLowerCase().contains("%2f")) {
    return false;
  }
  for (final segment in path.split("/")) {
    if (segment.isEmpty || segment == "." || segment == "..") return false;
  }
  return true;
}

Future<File?> _firstExisting(String basePath, List<String> extensions) async {
  for (final extension in extensions) {
    final file = File("$basePath$extension");
    if (await file.exists()) return file;
  }
  return null;
}

/// Whether [files] describes one coherent dictionary: exactly one format, the
/// pieces that format needs, and nothing belonging to a different base name.
void _validateFileSet(List<_DictionaryPackageFile> files) {
  int count(String role) => files.where((file) => file.role == role).length;

  final hasMdx = count("mdx") > 0;
  final hasStardict = files.any((file) => _stardictRoles.contains(file.role));
  // A package is exactly one format. Both or neither is a manifest no version
  // of this app wrote.
  if (hasMdx == hasStardict || files.length > 1000 || count("font") > 1) {
    throw const FormatException("Invalid dictionary package file set.");
  }

  if (hasMdx) {
    if (count("mdx") != 1 || count("css") > 1 || count("js") > 1) {
      throw const FormatException("Invalid dictionary package file set.");
    }
    final mdxStem = p.withoutExtension(
      files.singleWhere((file) => file.role == "mdx").remoteName,
    );
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
    return;
  }

  // StarDict: the three files it must have, plus the optional extras. Up to
  // three resource archives, one per place the reader looks.
  if (count("ifo") != 1 ||
      count("idx") != 1 ||
      count("dict") != 1 ||
      count("syn") > 1 ||
      count("res") > 3 ||
      count("resdir") > maxResourceDirectoryFiles) {
    throw const FormatException("Invalid dictionary package file set.");
  }
  final stem = _stardictStem(
    files.singleWhere((file) => file.role == "ifo").remoteName,
  );
  if (stem.isEmpty) {
    throw const FormatException("Invalid dictionary package file set.");
  }
  for (final file in files) {
    final validAssociation = switch (file.role) {
      "ifo" ||
      "idx" ||
      "dict" ||
      "syn" => _stardictStem(file.remoteName) == stem,
      "res" => _isResourceArchive(file.remoteName, stem),
      // The path shape is already pinned by [_validRemoteName]; a resource
      // file need not share the dictionary's base name.
      "resdir" => true,
      "font" => true,
      _ => false,
    };
    if (!validAssociation) {
      throw const FormatException(
        "Dictionary resource does not match its .ifo file.",
      );
    }
  }
}

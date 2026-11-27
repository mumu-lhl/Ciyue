import "dart:async";
import "dart:io";

import "package:archive/archive_io.dart";
import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/http_client.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/store.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/hunspell.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/services/hunspell.dart";
import "package:ciyue/services/mdd_reader_pool.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:dict_reader/dict_reader.dart";
import "package:dio/dio.dart";
import "package:drift/drift.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

const defaultStoreCatalogUrl =
    "https://raw.githubusercontent.com/mumu-lhl/Ciyue-Store/main/catalog.yaml";

typedef StoreDownloadProgressCallback = void Function(
  int receivedBytes,
  int totalBytes,
);

/// Rewrites a download or catalog URL according to the user's global mirror
/// settings.
///
/// `api.github.com` is never rewritten because third-party file/CDN mirrors
/// generally do not proxy GitHub's REST API.
String applyStoreMirror(
  String url, {
  StoreMirrorMode? mode,
  String? customPrefix,
}) {
  final effectiveMode = mode ?? settings.storeMirrorMode;
  if (effectiveMode == StoreMirrorMode.none) return url;

  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme("http") || uri.isScheme("https"))) {
    return url;
  }
  if (uri.host == "api.github.com") {
    return url;
  }

  switch (effectiveMode) {
    case StoreMirrorMode.none:
      return url;
    case StoreMirrorMode.jsdelivr:
      if (uri.host == "raw.githubusercontent.com" &&
          uri.pathSegments.length >= 4) {
        final owner = uri.pathSegments[0];
        final repo = uri.pathSegments[1];
        final branch = uri.pathSegments[2];
        final filePath = uri.pathSegments.sublist(3).join("/");
        return "https://cdn.jsdelivr.net/gh/$owner/$repo@$branch/$filePath";
      }
      return url;
    case StoreMirrorMode.custom:
      final prefix = (customPrefix ?? settings.storeCustomMirrorPrefix).trim();
      if (prefix.isEmpty) return url;
      if (uri.host == "github.com" || uri.host == "raw.githubusercontent.com") {
        final normalizedPrefix = prefix.endsWith("/") || prefix.endsWith("=")
            ? prefix
            : "$prefix/";
        return "$normalizedPrefix$url";
      }
      return url;
  }
}

/// Simple wildcard (`*` and `?`) matcher for GitHub Release asset names.
bool matchStoreAssetPattern(String filename, String pattern) {
  final escaped = RegExp.escape(pattern)
      .replaceAll(r"\*", ".*")
      .replaceAll(r"\?", ".");
  return RegExp("^$escaped\$", caseSensitive: false).hasMatch(filename);
}

/// Returns the expected size of a downloaded file, or null when the response
/// body is encoded and `Content-Length` does not describe the decoded file.
int? storeDownloadExpectedLength({
  String? contentLength,
  String? contentEncoding,
}) {
  if (contentEncoding != null && contentEncoding.isNotEmpty) return null;
  return int.tryParse(contentLength ?? "");
}

class StoreReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;
  final String? updatedAt;

  const StoreReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    this.updatedAt,
  });
}

class StoreReleaseInfo {
  final String tagName;
  final String? publishedAt;
  final List<StoreReleaseAsset> assets;

  const StoreReleaseInfo({
    required this.tagName,
    this.publishedAt,
    required this.assets,
  });

  String get versionToken => "$tagName@${publishedAt ?? ""}";
}

class StoreResolvedDownload {
  final List<StoreDirectFile> files;
  final String? remoteVersion;

  const StoreResolvedDownload({
    required this.files,
    required this.remoteVersion,
  });
}

class _CachedResponse {
  final dynamic data;
  final String? etag;
  final DateTime fetchedAt;

  const _CachedResponse({
    required this.data,
    required this.etag,
    required this.fetchedAt,
  });
}

class StoreService {
  static final StoreService instance = StoreService();

  static const _cacheTtl = Duration(minutes: 30);

  StoreCatalog? _cachedCatalog;
  String? _cachedCatalogUrl;
  DateTime? _cachedCatalogAt;
  final Map<String, _CachedResponse> _apiCache = {};

  String get activeCatalogUrl {
    final custom = settings.storeCatalogUrl.trim();
    return custom.isEmpty ? defaultStoreCatalogUrl : custom;
  }

  Future<StoreCatalog> fetchCatalog({bool forceRefresh = false}) async {
    final url = applyStoreMirror(activeCatalogUrl);
    if (!forceRefresh &&
        _cachedCatalog != null &&
        _cachedCatalogUrl == url &&
        _cachedCatalogAt != null &&
        DateTime.now().difference(_cachedCatalogAt!) < _cacheTtl) {
      return _cachedCatalog!;
    }

    final response = await AppHttp.dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data;
    if (body == null || body.trim().isEmpty) {
      throw const FormatException("Empty catalog response");
    }

    final catalog = StoreCatalogParser.parse(
      body,
      onWarning: (msg) => talker.warning("[Store] $msg"),
    );
    _cachedCatalog = catalog;
    _cachedCatalogUrl = url;
    _cachedCatalogAt = DateTime.now();
    return catalog;
  }

  /// Checks whether an installed item has a newer remote version.
  ///
  /// Only `github_release` and `github_raw` support automatic update checks;
  /// `direct` items rely on manual re-download.
  Future<bool> hasUpdate(
    StoreItem item,
    StoreInstalledItem installed, {
    bool forceRefresh = false,
  }) async {
    try {
      final latestVersion = await fetchLatestRemoteVersion(
        item,
        forceRefresh: forceRefresh,
      );
      if (latestVersion == null) return false;
      if (installed.remoteVersion == null || installed.remoteVersion!.isEmpty) {
        return true;
      }
      return latestVersion != installed.remoteVersion;
    } catch (e) {
      talker.warning("[Store] Update check failed for ${item.id}: $e");
      return false;
    }
  }

  Future<String?> fetchLatestRemoteVersion(
    StoreItem item, {
    bool forceRefresh = false,
  }) async {
    switch (item.source.type) {
      case StoreSourceType.githubRelease:
        final release = await fetchReleaseInfo(
          item.source.repo!,
          tag: item.source.tag,
          forceRefresh: forceRefresh,
        );
        return release.versionToken;
      case StoreSourceType.githubRaw:
        final branch = item.source.branch ?? "main";
        final firstFile = item.source.rawFiles.first;
        return fetchRawFileVersion(
          item.source.repo!,
          branch,
          firstFile,
          forceRefresh: forceRefresh,
        );
      case StoreSourceType.direct:
        return null;
    }
  }

  Future<StoreReleaseInfo> fetchReleaseInfo(
    String repo, {
    String? tag,
    bool forceRefresh = false,
  }) async {
    final endpoint = tag == null || tag.isEmpty
        ? "https://api.github.com/repos/$repo/releases/latest"
        : "https://api.github.com/repos/$repo/releases/tags/$tag";
    final data = await _getGitHubJson(endpoint, forceRefresh: forceRefresh);
    if (data is! Map) {
      throw const FormatException("Unexpected GitHub release response");
    }

    final rawAssets = data["assets"] as List<dynamic>? ?? const [];
    final assets = <StoreReleaseAsset>[];
    for (final raw in rawAssets) {
      if (raw is! Map) continue;
      final name = raw["name"]?.toString() ?? "";
      final downloadUrl = raw["browser_download_url"]?.toString() ?? "";
      if (name.isEmpty || downloadUrl.isEmpty) continue;
      assets.add(
        StoreReleaseAsset(
          name: name,
          downloadUrl: downloadUrl,
          size: (raw["size"] as num?)?.toInt() ?? 0,
          updatedAt: raw["updated_at"]?.toString(),
        ),
      );
    }

    return StoreReleaseInfo(
      tagName: data["tag_name"]?.toString() ?? "",
      publishedAt: data["published_at"]?.toString(),
      assets: assets,
    );
  }

  Future<String?> fetchRawFileVersion(
    String repo,
    String branch,
    String filePath, {
    bool forceRefresh = false,
  }) async {
    final encodedBranch = Uri.encodeQueryComponent(branch);
    final encodedPath = Uri.encodeQueryComponent(filePath);
    final endpoint =
        "https://api.github.com/repos/$repo/commits?sha=$encodedBranch&path=$encodedPath&per_page=1";
    final data = await _getGitHubJson(endpoint, forceRefresh: forceRefresh);
    if (data is! List || data.isEmpty) return null;
    final first = data.first;
    if (first is! Map) return null;
    final sha = first["sha"]?.toString() ?? "";
    final commit = first["commit"];
    final date = commit is Map
        ? (commit["committer"] is Map
              ? commit["committer"]["date"]?.toString()
              : null)
        : null;
    if (sha.isEmpty) return null;
    return "$sha@${date ?? ""}";
  }

  Future<dynamic> _getGitHubJson(
    String url, {
    bool forceRefresh = false,
  }) async {
    final cached = _apiCache[url];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.data;
    }

    final headers = <String, String>{
      "Accept": "application/vnd.github+json",
      if (cached?.etag != null) "If-None-Match": cached!.etag!,
    };

    final response = await AppHttp.dio.get<dynamic>(
      url,
      options: Options(
        headers: headers,
        validateStatus: (status) =>
            status != null &&
            ((status >= 200 && status < 300) || status == 304),
      ),
    );

    if (response.statusCode == 304 && cached != null) {
      _apiCache[url] = _CachedResponse(
        data: cached.data,
        etag: cached.etag,
        fetchedAt: DateTime.now(),
      );
      return cached.data;
    }

    final etag = response.headers.value("etag");
    _apiCache[url] = _CachedResponse(
      data: response.data,
      etag: etag,
      fetchedAt: DateTime.now(),
    );
    return response.data;
  }

  Future<StoreResolvedDownload> resolveDownload(StoreItem item) async {
    switch (item.source.type) {
      case StoreSourceType.githubRelease:
        final release = await fetchReleaseInfo(
          item.source.repo!,
          tag: item.source.tag,
          forceRefresh: true,
        );
        final matched = <StoreDirectFile>[];
        for (final pattern in item.source.assetPatterns) {
          for (final asset in release.assets) {
            if (matchStoreAssetPattern(asset.name, pattern) &&
                !matched.any((e) => e.filename == asset.name)) {
              matched.add(
                StoreDirectFile(url: asset.downloadUrl, filename: asset.name),
              );
            }
          }
        }
        if (matched.isEmpty) {
          throw StateError(
            "No release assets matched ${item.source.assetPatterns.join(', ')}",
          );
        }
        return StoreResolvedDownload(
          files: matched,
          remoteVersion: release.versionToken,
        );

      case StoreSourceType.githubRaw:
        final repo = item.source.repo!;
        final branch = item.source.branch ?? "main";
        final files = item.source.rawFiles
            .map((filePath) {
              final cleanPath = filePath.startsWith("/")
                  ? filePath.substring(1)
                  : filePath;
              return StoreDirectFile(
                url:
                    "https://raw.githubusercontent.com/$repo/$branch/$cleanPath",
                filename: p.basename(cleanPath),
              );
            })
            .toList(growable: false);

        String? remoteVersion;
        try {
          remoteVersion = await fetchRawFileVersion(
            repo,
            branch,
            item.source.rawFiles.first,
            forceRefresh: true,
          );
        } catch (e) {
          talker.warning(
            "[Store] Could not fetch commit version for ${item.id}: $e",
          );
        }
        return StoreResolvedDownload(
          files: files,
          remoteVersion: remoteVersion,
        );

      case StoreSourceType.direct:
        return StoreResolvedDownload(
          files: item.source.directFiles,
          remoteVersion: null,
        );
    }
  }

  Future<Directory> _managedItemDirectory(StoreItem item) async {
    final supportDir = await getApplicationSupportDirectory();
    final category = switch (item.type) {
      StoreItemType.dictionary => "dictionaries",
      StoreItemType.hunspell => "hunspell",
      StoreItemType.audio => "audio",
    };
    return Directory(p.join(supportDir.path, "store", category, item.id));
  }

  Future<StoreInstalledItem> downloadAndInstall(
    StoreItem item, {
    required CancelToken cancelToken,
    StoreDownloadProgressCallback? onProgress,
  }) async {
    final resolved = await resolveDownload(item);
    final supportDir = await getApplicationSupportDirectory();
    final tmpDir = Directory(
      p.join(
        supportDir.path,
        "store",
        ".tmp",
        "${item.id}_${DateTime.now().millisecondsSinceEpoch}",
      ),
    );
    await tmpDir.create(recursive: true);

    try {
      final downloadedFiles = <File>[];
      final totalFiles = resolved.files.length;

      for (var i = 0; i < totalFiles; i++) {
        final spec = resolved.files[i];
        final downloadUrl = applyStoreMirror(spec.url);
        final destFile = File(p.join(tmpDir.path, spec.filename));
        await destFile.parent.create(recursive: true);

        final response = await AppHttp.dio.download(
          downloadUrl,
          destFile.path,
          options: Options(headers: {"accept-encoding": "identity"}),
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (onProgress == null) return;
            if (totalFiles == 1) {
              onProgress(received, total);
            } else if (total > 0) {
              final perFileSlice = 100000;
              final overallReceived =
                  (i * perFileSlice) + ((received * perFileSlice) ~/ total);
              onProgress(overallReceived, totalFiles * perFileSlice);
            } else {
              onProgress(i, totalFiles);
            }
          },
        );

        final status = response.statusCode ?? 0;
        if (status < 200 || status >= 300) {
          throw HttpException("Download failed with HTTP $status");
        }
        if (!await destFile.exists() || await destFile.length() == 0) {
          throw const FileSystemException("Downloaded file is empty");
        }
        final expectedLength = storeDownloadExpectedLength(
          contentLength: response.headers.value(Headers.contentLengthHeader),
          contentEncoding: response.headers.value("content-encoding"),
        );
        if (expectedLength != null && expectedLength > 0) {
          final actualLength = await destFile.length();
          if (actualLength != expectedLength) {
            throw FileSystemException(
              "Incomplete download ($actualLength / $expectedLength bytes)",
              destFile.path,
            );
          }
        }
        downloadedFiles.add(destFile);
      }

      // Close active readers before replacing files on disk when updating.
      final existing = await storeInstalledItemDao.getById(item.id);
      final existingTargetIds = _parseTargetIds(existing?.targetIds);
      await _prepareExistingTargetsForOverwrite(item, existingTargetIds);

      final targetDir = await _managedItemDirectory(item);
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      await targetDir.create(recursive: true);

      if (item.extract) {
        for (final file in downloadedFiles) {
          await _extractZipSafely(file, targetDir);
        }
      } else {
        for (final file in downloadedFiles) {
          final dest = File(p.join(targetDir.path, p.basename(file.path)));
          await file.copy(dest.path);
        }
      }

      final newTargetIds = await _registerInstalledFiles(
        item,
        targetDir,
        existingTargetIds,
      );

      final now = DateTime.now();
      await storeInstalledItemDao.upsert(
        StoreInstalledItemsCompanion(
          itemId: Value(item.id),
          type: Value(item.type.name),
          format: Value(item.format.name),
          installDir: Value(targetDir.path),
          remoteVersion: Value(resolved.remoteVersion),
          installedAt: Value(now),
          targetIds: Value(newTargetIds.join(",")),
        ),
      );

      return (await storeInstalledItemDao.getById(item.id))!;
    } finally {
      if (await tmpDir.exists()) {
        try {
          await tmpDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<void> _extractZipSafely(File zipFile, Directory targetDir) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.isEmpty) {
      throw FormatException("Archive ${p.basename(zipFile.path)} is empty");
    }

    final canonicalRoot = p.normalize(targetDir.absolute.path);
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final outPath = p.normalize(p.join(canonicalRoot, entry.name));
      if (!p.isWithin(canonicalRoot, outPath)) {
        throw FormatException("Unsafe archive path: ${entry.name}");
      }
      final outFile = File(outPath);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>);
    }
  }

  Future<void> _prepareExistingTargetsForOverwrite(
    StoreItem item,
    List<int> existingTargetIds,
  ) async {
    if (existingTargetIds.isEmpty) return;

    switch (item.type) {
      case StoreItemType.dictionary:
        for (final id in existingTargetIds) {
          await dictManager.close(id);
        }
      case StoreItemType.hunspell:
        await hunspellManager.close();
      case StoreItemType.audio:
        for (final id in existingTargetIds) {
          final existingAudio = (await mddAudioListDao.allOrdered())
              .where((e) => e.id == id)
              .firstOrNull;
          if (existingAudio != null) {
            closeZipAudioReader(existingAudio.path);
            await closeMddReader(existingAudio.path);
          }
        }
    }
  }

  Future<List<int>> _registerInstalledFiles(
    StoreItem item,
    Directory targetDir,
    List<int> existingTargetIds,
  ) async {
    switch (item.type) {
      case StoreItemType.dictionary:
        return _registerDictionary(item, targetDir, existingTargetIds);
      case StoreItemType.hunspell:
        return _registerHunspell(targetDir, existingTargetIds);
      case StoreItemType.audio:
        return _registerAudioPacks(item, targetDir, existingTargetIds);
    }
  }

  Future<List<int>> _registerDictionary(
    StoreItem item,
    Directory targetDir,
    List<int> existingTargetIds,
  ) async {
    final targetExtension = switch (item.format) {
      StoreItemFormat.stardict => ".ifo",
      StoreItemFormat.zim => ".zim",
      _ => ".mdx",
    };

    final found = <File>[];
    await for (final entity in targetDir.list(recursive: true)) {
      if (entity is File &&
          p.extension(entity.path).toLowerCase() == targetExtension) {
        found.add(entity);
      }
    }
    if (found.isEmpty) {
      throw FileSystemException(
        "No $targetExtension file found after installation",
        targetDir.path,
      );
    }

    found.sort((a, b) => a.path.compareTo(b.path));
    final dictFile = found.first;
    final dictBasePath = p.withoutExtension(dictFile.path);
    final dictType = switch (item.format) {
      StoreItemFormat.stardict => DictionaryType.stardict,
      StoreItemFormat.zim => DictionaryType.zim,
      _ => 1,
    };

    if (existingTargetIds.isNotEmpty) {
      final existingId = existingTargetIds.first;
      final existingRow = (await dictionaryListDao.all())
          .where((e) => e.id == existingId)
          .firstOrNull;
      if (existingRow != null) {
        await (mainDatabase.update(
          mainDatabase.dictionaryList,
        )..where((t) => t.id.isValue(existingId))).write(
          DictionaryListCompanion(
            path: Value(dictBasePath),
            type: Value(dictType),
          ),
        );
        if (dictManager.dictIds.contains(existingId)) {
          await dictManager.add(existingId, dictBasePath);
        }
        return [existingId];
      }
    }

    final newId = await dictionaryListDao.add(
      dictBasePath,
      item.name,
      type: dictType,
    );
    final groupIds = await dictGroupDao.getDictIds(dictManager.groupId);
    if (!groupIds.contains(newId)) {
      groupIds.add(newId);
      await dictGroupDao.updateDictIds(dictManager.groupId, groupIds);
      dictManager.dictIds = groupIds;
    }
    await dictManager.add(newId, dictBasePath);
    return [newId];
  }

  Future<List<int>> _registerHunspell(
    Directory targetDir,
    List<int> existingTargetIds,
  ) async {
    final pairs = await findHunspellPairs(targetDir);
    if (pairs.isEmpty) {
      throw FileSystemException(
        "No valid .aff/.dic Hunspell pair found",
        targetDir.path,
      );
    }

    if (existingTargetIds.isNotEmpty && pairs.length == 1) {
      final existingId = existingTargetIds.first;
      final existingRow = (await hunspellSourceDao.all())
          .where((e) => e.id == existingId)
          .firstOrNull;
      if (existingRow != null) {
        await (mainDatabase.update(
          mainDatabase.hunspellSource,
        )..where((t) => t.id.isValue(existingId))).write(
          HunspellSourceCompanion(
            affPath: Value(pairs.first.affPath),
            dicPath: Value(pairs.first.dicPath),
          ),
        );
        await reloadHunspellFromDatabase();
        return [existingId];
      }
    }

    final registeredIds = <int>[];
    final groupId = dictManager.groupId;
    final memberIds = await dictGroupDao.getHunspellIds(groupId);
    for (final pair in pairs) {
      final existing = (await hunspellSourceDao.all())
          .where((s) => s.affPath == pair.affPath && s.dicPath == pair.dicPath)
          .firstOrNull;
      final id =
          existing?.id ??
          await hunspellSourceDao.add(
            name: pair.name,
            affPath: pair.affPath,
            dicPath: pair.dicPath,
            enabled: true,
          );
      registeredIds.add(id);
      if (!memberIds.contains(id)) memberIds.add(id);
    }
    await dictGroupDao.updateHunspellIds(groupId, memberIds);
    await reloadHunspellFromDatabase(groupId: groupId);
    return registeredIds;
  }

  Future<List<int>> _registerAudioPacks(
    StoreItem item,
    Directory targetDir,
    List<int> existingTargetIds,
  ) async {
    final files = <File>[];
    await for (final entity in targetDir.list(recursive: true)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase().replaceFirst(".", "");
      if (audioPackExtensions.contains(ext)) {
        files.add(entity);
      }
    }
    if (files.isEmpty) {
      throw FileSystemException(
        "No audio pack (.mdd/.zip/.zips) found",
        targetDir.path,
      );
    }
    files.sort((a, b) => a.path.compareTo(b.path));

    if (existingTargetIds.isNotEmpty && files.length == 1) {
      final existingId = existingTargetIds.first;
      final existingRow = (await mddAudioListDao.allOrdered())
          .where((e) => e.id == existingId)
          .firstOrNull;
      if (existingRow != null) {
        final filePath = files.first.path;
        await (mainDatabase.update(mainDatabase.mddAudioList)
              ..where((t) => t.id.isValue(existingId)))
            .write(MddAudioListCompanion(path: Value(filePath)));
        await mddAudioResourceDao.remove(existingId);
        if (!isZipAudioPack(filePath)) {
          await _indexMddAudioFile(existingId, filePath);
        }
        await AudioModel.instance?.init();
        return [existingId];
      }
    }

    final registeredIds = <int>[];
    for (final file in files) {
      final filePath = file.path;
      final title = files.length == 1
          ? item.name
          : p.basenameWithoutExtension(filePath);
      final id = await mddAudioListDao.add(filePath, title);
      if (!isZipAudioPack(filePath)) {
        await _indexMddAudioFile(id, filePath);
      }
      registeredIds.add(id);
    }
    await AudioModel.instance?.init();
    return registeredIds;
  }

  Future<void> _indexMddAudioFile(int mddAudioListId, String filePath) async {
    final reader = DictReader(filePath);
    await reader.initDict();
    final resources = <MddAudioResourceCompanion>[];
    await for (final info in reader.readWithOffset()) {
      resources.add(
        MddAudioResourceCompanion(
          key: Value(info.keyText),
          blockOffset: Value(info.recordBlockOffset),
          startOffset: Value(info.startOffset),
          endOffset: Value(info.endOffset),
          compressedSize: Value(info.compressedSize),
          mddAudioListId: Value(mddAudioListId),
        ),
      );
    }
    if (resources.isNotEmpty) {
      await mddAudioResourceDao.add(resources);
    }
    await reader.close();
  }

  Future<void> uninstall(StoreInstalledItem installed) async {
    final targetIds = _parseTargetIds(installed.targetIds);
    final type = StoreItemType.tryParse(installed.type);

    switch (type) {
      case StoreItemType.dictionary:
        for (final id in targetIds) {
          await dictManager.close(id);
          final path = await dictionaryListDao.getPath(id);
          if (path != null) {
            await dictionaryListDao.remove(path);
          }
          await dictGroupDao.removeDictIdFromAllGroups(id);
        }
      case StoreItemType.hunspell:
        for (final id in targetIds) {
          await removeHunspellSource(id);
        }
      case StoreItemType.audio:
        for (final id in targetIds) {
          final row = (await mddAudioListDao.allOrdered())
              .where((e) => e.id == id)
              .firstOrNull;
          if (row != null) {
            closeZipAudioReader(row.path);
            await closeMddReader(row.path);
          }
          await mddAudioListDao.remove(id);
          await mddAudioResourceDao.remove(id);
        }
        await AudioModel.instance?.init();
      case null:
        break;
    }

    final dir = Directory(installed.installDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await storeInstalledItemDao.remove(installed.itemId);
  }

  static List<int> _parseTargetIds(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(",")
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList(growable: false);
  }
}

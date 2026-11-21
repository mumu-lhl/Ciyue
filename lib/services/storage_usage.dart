import "dart:convert";
import "dart:io";
import "dart:isolate";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/utils.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

/// One row of the Telegram-style storage page: how much space a category
/// uses, and whether the page may offer to delete it. [bytes] is null when
/// the size cannot be measured — the dictionaries can live behind a
/// `content://` URI on Android (see #800), which Dart cannot stat.
class StorageUsage {
  const StorageUsage({
    required this.kind,
    required this.bytes,
    required this.clearable,
  });

  final StorageCategoryKind kind;

  /// On-disk size in bytes, or null when it cannot be measured.
  final int? bytes;

  /// Whether the storage page offers a delete action for this category.
  /// Everything clearable here is rebuildable: the full-text index and the
  /// `.cidx` files rebuild on the next search or rescan, the pronunciation
  /// audio downloads again, and the rest of the cache directory is data
  /// the system itself may purge.
  final bool clearable;
}

enum StorageCategoryKind {
  dictionaries,
  fullTextIndex,
  dictionaryIndexCache,
  pronunciationCache,
  otherCache,
  database,
  audioPacks,
  chatImages,
}

/// Estimated size of one personal dictionary's content: how much space
/// its entries occupy, and how many entries that covers. The number is a
/// content estimate, not on-disk usage — every personal dictionary shares
/// the `dictionary_list.sqlite` file, so no exact per-dictionary byte
/// count exists; see [estimatePersonalDictionaryBytes].
class PersonalDictionaryStorageEstimate {
  const PersonalDictionaryStorageEstimate({
    required this.dictionaryId,
    required this.title,
    required this.entryCount,
    required this.estimatedBytes,
  });

  final int dictionaryId;
  final String title;
  final int entryCount;

  /// Estimated content size in bytes (see [estimatePersonalDictionaryBytes]).
  final int estimatedBytes;
}

/// Estimates how many bytes [entries] occupy: the stored definition
/// bodies plus headwords, measured as UTF-8 bytes. The database file
/// itself also holds page overhead, indexes and free pages shared by all
/// personal dictionaries, so this is a lower-bound content estimate, not
/// an exact attribution — but it is what the storage page can show per
/// dictionary, where the shared file's total cannot be split.
int estimatePersonalDictionaryBytes(Iterable<PersonalEntry> entries) {
  var total = 0;
  for (final entry in entries) {
    total += utf8.encode(entry.body).length;
    for (final headword in entry.headwords) {
      total += utf8.encode(headword).length;
    }
  }
  return total;
}

/// Human-readable byte size, matching the format the dictionary pages use:
/// `512 B`, `1.5 KB`, `2.0 MB`, `1.2 GB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return "$bytes B";
  final kibibytes = bytes / 1024;
  if (kibibytes < 1024) return "${kibibytes.toStringAsFixed(1)} KB";
  final mebibytes = kibibytes / 1024;
  if (mebibytes < 1024) return "${mebibytes.toStringAsFixed(1)} MB";
  return "${(mebibytes / 1024).toStringAsFixed(1)} GB";
}

/// Measures how much space each storage category uses, and deletes the
/// rebuildable cache categories. Sizes are computed in a background isolate
/// (only plain path strings cross over), because a dictionary directory can
/// hold thousands of files. Deletions run on the main isolate and are
/// best-effort: an entry that cannot be deleted (for example a file the
/// WebView still holds open on Windows) is skipped, not fatal.
class StorageUsageService {
  StorageUsageService({
    Future<Directory> Function()? cacheDirectory,
    Future<Directory> Function()? supportDirectory,
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? databaseDir,
    Future<String?> Function()? dictionariesDirectoryPath,
    Future<List<PersonalDictionaryStorageEstimate>> Function()?
    personalDictionaryEstimates,
  }) : _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _databaseDirectory = databaseDir ?? databaseDirectory,
       _dictionariesDirectoryPath =
           dictionariesDirectoryPath ?? _defaultDictionariesDirectoryPath,
       _personalDictionaryEstimates = // ignore: prefer_initializing_formals
           personalDictionaryEstimates;

  final Future<Directory> Function() _cacheDirectory;
  final Future<Directory> Function() _supportDirectory;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _databaseDirectory;
  final Future<String?> Function() _dictionariesDirectoryPath;

  /// Per-dictionary content estimates for the storage page's breakdown
  /// under the database category (see [PersonalDictionaryStorageEstimate]).
  /// Null when the caller cannot provide personal-dictionary data, in
  /// which case [measurePersonalDictionaries] returns an empty list.
  final Future<List<PersonalDictionaryStorageEstimate>> Function()?
  _personalDictionaryEstimates;

  static Future<String?> _defaultDictionariesDirectoryPath() async {
    final pref = prefs.getString("dictionariesDirectory");
    if (pref != null) return pref;
    final support = await getApplicationSupportDirectory();
    return p.join(support.path, "dictionaries");
  }

  /// Measures every category. The order matches the page: dictionaries
  /// first, then the clearable caches, then the rest.
  Future<List<StorageUsage>> measure() async {
    final cache = await _cacheDirectory();
    final support = await _supportDirectory();
    // getApplicationDocumentsDirectory() throws
    // MissingPlatformDirectoryException on Linux systems without a
    // documents folder (no XDG documents dir). Chat images live under
    // that folder, so without one there can be none — count them as
    // empty instead of failing the whole measurement. The other
    // providers still throw, and refresh() turns that into the page's
    // error state with a retry button.
    Directory? documents;
    try {
      documents = await _documentsDirectory();
    } on MissingPlatformDirectoryException {
      documents = null;
    }
    final database = await _databaseDirectory();
    final dictionaries = await _dictionariesDirectoryPath();
    final sizes = await Isolate.run(
      () => _measureSync({
        "cache": cache.path,
        "support": support.path,
        "documents": documents?.path,
        "database": database.path,
        "dictionaries": dictionaries,
      }),
    );
    int? bytesOf(String key) {
      final value = sizes[key];
      if (value == null || value < 0) return null;
      return value;
    }

    return [
      StorageUsage(
        kind: StorageCategoryKind.dictionaries,
        bytes: bytesOf("dictionaries"),
        clearable: false,
      ),
      StorageUsage(
        kind: StorageCategoryKind.fullTextIndex,
        bytes: bytesOf("fullTextIndex"),
        clearable: true,
      ),
      StorageUsage(
        kind: StorageCategoryKind.dictionaryIndexCache,
        bytes: bytesOf("dictionaryIndexCache"),
        clearable: true,
      ),
      StorageUsage(
        kind: StorageCategoryKind.pronunciationCache,
        bytes: bytesOf("pronunciationCache"),
        clearable: true,
      ),
      StorageUsage(
        kind: StorageCategoryKind.otherCache,
        bytes: bytesOf("otherCache"),
        clearable: true,
      ),
      StorageUsage(
        kind: StorageCategoryKind.database,
        bytes: bytesOf("database"),
        clearable: false,
      ),
      StorageUsage(
        kind: StorageCategoryKind.audioPacks,
        bytes: bytesOf("audioPacks"),
        clearable: false,
      ),
      StorageUsage(
        kind: StorageCategoryKind.chatImages,
        bytes: bytesOf("chatImages"),
        clearable: false,
      ),
    ];
  }

  /// Per-dictionary personal-dictionary content estimates for the storage
  /// page, from the injected loader. Empty when no loader was provided or
  /// it fails: the breakdown is informational, and a failed estimate must
  /// not break the page's measurement. The estimates are NOT part of
  /// [measure]'s totals — the bytes live inside the shared database file
  /// already counted there.
  Future<List<PersonalDictionaryStorageEstimate>>
  measurePersonalDictionaries() async {
    final load = _personalDictionaryEstimates;
    if (load == null) return const [];
    try {
      return await load();
    } catch (_) {
      return const [];
    }
  }

  /// Deletes the per-dictionary binary index cache (`dict_reader_*.cidx`).
  /// Returns the bytes freed. The files rebuild on the next rescan.
  Future<int> clearDictionaryIndexCache() async {
    final cache = await _cacheDirectory();
    var freed = 0;
    await for (final entity in cache.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (_isDictionaryIndexCache(name)) {
        freed += await _delete(entity);
      }
    }
    return freed;
  }

  /// Deletes the downloaded pronunciation audio. Returns the bytes freed.
  /// The audio downloads again when it is needed.
  Future<int> clearPronunciationCache() async {
    final cache = await _cacheDirectory();
    final dir = Directory(p.join(cache.path, "online_pronunciation"));
    return _delete(dir);
  }

  /// Deletes everything else in the cache directory — the full-text index
  /// file, the `.cidx` files and the pronunciation cache are NOT touched
  /// here; each has its own clear action. Returns the bytes freed.
  Future<int> clearOtherCache() async {
    final cache = await _cacheDirectory();
    var freed = 0;
    await for (final entity in cache.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (_isFullTextIndexFile(name) ||
          _isDictionaryIndexCache(name) ||
          name == "online_pronunciation") {
        continue;
      }
      freed += await _delete(entity);
    }
    return freed;
  }

  /// Best-effort recursive delete: returns the size the entity occupied,
  /// or 0 when it does not exist or cannot be deleted.
  Future<int> _delete(FileSystemEntity entity) async {
    try {
      if (!await entity.exists()) return 0;
      final size = entity is Directory
          ? _dirSizeSync(entity)
          : entity is File
          ? await entity.length()
          : 0;
      await entity.delete(recursive: true);
      return size;
    } catch (_) {
      return 0;
    }
  }
}

bool _isFullTextIndexFile(String name) =>
    name == "full_text_search.db" ||
    name == "full_text_search.db-wal" ||
    name == "full_text_search.db-shm";

bool _isDictionaryIndexCache(String name) =>
    name.startsWith("dict_reader_") && name.endsWith(".cidx");

int _sizeOfSync(FileSystemEntity entity) {
  try {
    if (entity is File) return entity.lengthSync();
    if (entity is Directory) return _dirSizeSync(entity);
  } catch (_) {}
  return 0;
}

int _dirSizeSync(Directory dir) {
  var total = 0;
  try {
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      total += _sizeOfSync(entity);
    }
  } catch (_) {}
  return total;
}

/// Pure function over plain path strings, so [Isolate.run] can take it.
/// Returns bytes per category, with -1 for the dictionaries when their path
/// is not a measurable filesystem path (a `content://` URI on Android).
Map<String, int> _measureSync(Map<String, String?> roots) {
  var fullTextIndex = 0;
  var dictionaryIndexCache = 0;
  var pronunciationCache = 0;
  var otherCache = 0;

  final cache = Directory(roots["cache"]!);
  try {
    for (final entity in cache.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      final size = _sizeOfSync(entity);
      if (_isFullTextIndexFile(name)) {
        fullTextIndex += size;
      } else if (_isDictionaryIndexCache(name)) {
        dictionaryIndexCache += size;
      } else if (name == "online_pronunciation") {
        pronunciationCache += size;
      } else {
        otherCache += size;
      }
    }
  } catch (_) {}

  final support = Directory(roots["support"]!);
  final audioPacks = _dirSizeSync(Directory(p.join(support.path, "audios")));

  final database = Directory(roots["database"]!);
  var databaseBytes = 0;
  for (final name in [
    "dictionary_list.sqlite",
    "dictionary_list.sqlite-wal",
    "dictionary_list.sqlite-shm",
  ]) {
    databaseBytes += _sizeOfSync(File(p.join(database.path, name)));
  }

  final documentsPath = roots["documents"];
  final chatImages = documentsPath == null
      ? 0
      : _dirSizeSync(Directory(p.join(documentsPath, "chat_images")));

  final dictionariesPath = roots["dictionaries"];
  final dictionaries =
      dictionariesPath == null || dictionariesPath.startsWith("content://")
      ? -1
      : _dirSizeSync(Directory(dictionariesPath));

  return {
    "dictionaries": dictionaries,
    "fullTextIndex": fullTextIndex,
    "dictionaryIndexCache": dictionaryIndexCache,
    "pronunciationCache": pronunciationCache,
    "otherCache": otherCache,
    "database": databaseBytes,
    "audioPacks": audioPacks,
    "chatImages": chatImages,
  };
}

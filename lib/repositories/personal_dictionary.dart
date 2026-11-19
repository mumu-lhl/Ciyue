import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/base_dictionary.dart";
import "package:ciyue/services/lookup_keys.dart";
import "package:ciyue/utils.dart";
import "package:markdown/markdown.dart" as markdown;

/// Whether [path] is the sentinel path of a personal dictionary
/// (`personal:<id>`), rather than a file path.
bool isPersonalDictionaryPath(String path) => path.startsWith("personal:");

/// The dictionary id carried by a personal-dictionary sentinel path, or
/// null when [path] is not one.
int? personalDictionaryIdFromPath(String path) {
  if (!isPersonalDictionaryPath(path)) return null;
  return int.tryParse(path.substring("personal:".length));
}

/// A user-authored dictionary whose entries live in the app database
/// ([PersonalArticles] / [PersonalHeadwords]), not in a file.
///
/// [path] is the sentinel `personal:<id>` (see [isPersonalDictionaryPath]);
/// loading reads the [DictionaryList] row for that id and nothing else, so
/// a personal dictionary never touches the file system. Article bodies are
/// Markdown source, converted to HTML at read time so entries flow through
/// the existing word-display pipeline unchanged.
class PersonalDictionary extends BaseLoadedDictionary {
  /// A test database. Null in production, where the shared [mainDatabase]
  /// is used. Kept unresolved until first use so merely constructing a
  /// dictionary (e.g. in `createLoadedDictionary`) never opens the global
  /// database.
  final AppDatabase? _databaseOverride;

  PersonalDictionary({required super.path, AppDatabase? database})
    : _databaseOverride = database;

  AppDatabase get _db => _databaseOverride ?? mainDatabase;

  DictionaryListDao get _dictionaryListDao => DictionaryListDao(_db);

  PersonalDictionaryDao get _dao => PersonalDictionaryDao(_db);

  bool _metadataLoaded = false;

  /// True once the [DictionaryList] row has been read; a personal
  /// dictionary has no index or server to wait for, so metadata is all
  /// loading there is.
  @override
  bool get isReady => _metadataLoaded && initializationError == null;

  @override
  Future<void> initMetadata() =>
      metadataInitialization ??= _initializeMetadata();

  Future<void> _initializeMetadata() async {
    final parsedId = personalDictionaryIdFromPath(path);
    if (parsedId == null) {
      throw StateError("Personal dictionary path is not personal:<id>: $path");
    }
    id = parsedId;
    type = DictionaryType.personal;
    final row = await _dictionaryListDao.getById(id);
    if (row == null) {
      throw StateError("No personal dictionary with id $id");
    }
    if (row.type != DictionaryType.personal) {
      throw StateError(
        "Dictionary $id is not a personal dictionary (type ${row.type})",
      );
    }
    title = row.title ?? "personal:$id";
    entriesTotal = await _dao.countHeadwords(id);
    _metadataLoaded = true;
    isLoading = false;
  }

  @override
  Future<void> init() => initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      await initMetadata();
      entriesTotal = await _dao.countHeadwords(id);
      if (isDesktop()) {
        // The desktop entry WebView waits for this dictionary's loopback
        // server port before loading content (WebviewWindows gives up
        // when the port stays 0 after loading), so a personal dictionary
        // needs a server exactly like a file dictionary, even though it
        // serves no resources. Without it the word page shows the section
        // header but the entry body never loads.
        await startDesktopServer();
      }
    } catch (e) {
      initializationError = e;
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  @override
  Future<void> initOnlyMetadata(int id) async {
    this.id = id;
    type = DictionaryType.personal;
    final row = await _dictionaryListDao.getById(id);
    if (row == null) {
      throw StateError("No personal dictionary with id $id");
    }
    title = row.title ?? "personal:$id";
    entriesTotal = await _dao.countHeadwords(id);
    _metadataLoaded = true;
    isLoading = false;
  }

  @override
  Future<void> onClose() async {}

  /// Personal dictionaries have no description of their own.
  @override
  String get description => "";

  /// The stored title is the dictionary's own title, so there is nothing
  /// to reset to.
  @override
  void setDefaultTitle() {}

  @override
  Future<List<String>> search(String query) async {
    await waitForLoading();
    final normalized = normalizePersonalHeadword(query.trim());
    if (normalized.isEmpty) return [];
    try {
      final rows = await _dao.searchHeadwords(id, normalized);
      return rows.map((row) => row.headword).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Map<String, String>> resolveKeys(Iterable<String> words) async {
    await waitForLoading();
    final candidatesByNormalized = <String, List<String>>{};
    for (final word in words) {
      (candidatesByNormalized[normalizePersonalHeadword(word)] ??= []).add(
        word,
      );
    }
    if (candidatesByNormalized.isEmpty) return {};
    final rows = await _dao.resolveHeadwords(id, candidatesByNormalized.keys);
    final resolved = <String, String>{};
    for (final entry in candidatesByNormalized.entries) {
      final row = rows[entry.key];
      if (row == null) continue;
      for (final candidate in entry.value) {
        resolved[candidate] = row.headword;
      }
    }
    return resolved;
  }

  @override
  Future<List<DictionaryEntryData>> readExactEntries(
    Iterable<String> words, {
    Map<String, String>? resolvedKeys,
  }) async {
    final resolved = resolvedKeys ?? await resolveKeys(words);
    final headwords = <String>[];
    final seenHeadwords = <String>{};
    for (final word in words) {
      final headword = resolved[word];
      if (headword == null) continue;
      if (seenHeadwords.add(headword)) headwords.add(headword);
    }
    if (headwords.isEmpty) return [];
    final rows = await _dao.resolveHeadwords(
      id,
      headwords.map(normalizePersonalHeadword),
    );
    final entries = <DictionaryEntryData>[];
    for (final headword in headwords) {
      final row = rows[normalizePersonalHeadword(headword)];
      if (row == null) continue;
      final article = await _dao.getArticle(row.articleId);
      if (article == null) continue;
      entries.add(
        DictionaryEntryData(
          headword: row.headword,
          content: markdown.markdownToHtml(article.body),
        ),
      );
    }
    return entries;
  }

  /// Personal entries are already HTML (converted from Markdown at read
  /// time) and carry no resources, so there is nothing to wrap.
  @override
  String wrapContentWithResources(String content) => content;

  /// Personal dictionaries have no resource files.
  @override
  Future<Uint8List?> readResourceFile(String filename) async => null;

  /// Deletes the dictionary's articles and headwords plus its
  /// [DictionaryList] row. No file path is involved: the sentinel path is
  /// not a file, and personal dictionaries own no files.
  @override
  Future<void> removeDictionary({int? dictionaryId}) async {
    final removeId = dictionaryId ?? id;
    await _dao.deleteDictionaryData(removeId);
    await _dictionaryListDao.removeById(removeId);
  }
}

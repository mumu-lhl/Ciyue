abstract interface class DictionarySource {
  int get id;

  Future<String?> resolveExactKey(String word);

  Future<List<String>> search(String query);

  Future<List<DictionaryEntryData>> readExactEntries(Iterable<String> words);
}

/// Values stored in the dictionary list's `type` column.
///
/// MDict dictionaries carry 0 (legacy rows) or 1 (everything the current
/// add pipeline writes); only StarDict needs its own value because the
/// formats load through different readers.
abstract final class DictionaryType {
  static const int stardict = 2;

  static bool isStardict(int type) => type == stardict;
}

/// A dictionary loaded by the dictionary manager, regardless of its file
/// format. Format-specific classes ([Mdict] for MDict, `Stardict` for
/// StarDict) implement this so shared code — the manager, lookup and the
/// word display — never names a format it does not need.
abstract interface class LoadedDictionary implements DictionarySource {
  @override
  int get id;

  /// Base path of the dictionary files, without an extension. The format's
  /// companion files share this path.
  String get path;

  String get title;

  set title(String value);

  /// The stored [DictionaryType] value for this dictionary.
  int get type;

  int get entriesTotal;

  /// Port of the local content server on desktop, or 0 when not running.
  int get port;

  bool get isLoading;

  /// Whether loading finished successfully and entries can be served.
  bool get isReady;

  /// The dictionary's own description (MDict header / StarDict .ifo),
  /// as raw HTML or plain text; empty when the dictionary provides none.
  String get description;

  /// Reads the id, type and title from storage plus the file header.
  Future<void> initMetadata();

  /// Full load: index, resources and the content server.
  Future<void> init();

  /// Metadata-only load for a dictionary identified by [id], used when the
  /// dictionary is not part of the active group.
  Future<void> initOnlyMetadata(int id);

  Future<void> waitForLoading();

  Future<void> close({bool waitForLoading = true});

  /// Resets the stored title to the dictionary's own (header) title.
  void setDefaultTitle();

  /// Prepares entry HTML for display, e.g. by prepending the dictionary's
  /// stylesheet/script tags when the format has them.
  String wrapContentWithResources(String content);

  /// Removes the dictionary from storage, including its cached data and,
  /// where the platform keeps app-owned copies, its files.
  Future<void> removeDictionary({int? dictionaryId});
}

class DictionaryEntryData {
  final String headword;
  final String content;

  const DictionaryEntryData({required this.headword, required this.content});
}

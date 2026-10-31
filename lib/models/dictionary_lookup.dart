import "dart:typed_data";

abstract interface class DictionarySource {
  int get id;

  Future<String?> resolveExactKey(String word);

  /// Resolves many candidates at once, answering with the spelling the
  /// dictionary actually holds for each of [words] it knows.
  ///
  /// Word splitting asks "is this slice a headword?" hundreds of times for a
  /// single query, and every spelling variant multiplies that. Answering them
  /// in one call keeps it to one `await` per dictionary instead of one per
  /// probe; implementations loop over the index in memory, where each check is
  /// a binary search.
  Future<Map<String, String>> resolveKeys(Iterable<String> words);

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
  static const int zim = 3;

  static bool isStardict(int type) => type == stardict;
  static bool isZim(int type) => type == zim;
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

  /// Reads a binary resource (image, sound, stylesheet, script) by path,
  /// or returns null if not found.
  Future<Uint8List?> readResourceFile(String filename);

  /// Removes the dictionary from storage, including its cached data and,
  /// where the platform keeps app-owned copies, its files.
  Future<void> removeDictionary({int? dictionaryId});
}

class DictionaryEntryData {
  final String headword;
  final String content;

  const DictionaryEntryData({required this.headword, required this.content});
}

/// One way to read a long word as several headwords, in reading order.
///
/// The parts carry the spelling the dictionary uses, so a query typed as
/// `animecover` shows `Anime` and `Cover`.
class WordSplit {
  final List<String> parts;

  const WordSplit(this.parts);

  /// `Anime + Cover`, for display and for test assertions.
  String get display => parts.join(" + ");
}

/// What the "not found" page can offer instead of a dead end.
class MissingWordSuggestions {
  /// Words the morphology engine believes the query was meant to be.
  final List<String> spellingSuggestions;

  /// Readings of the query as several known headwords.
  final List<WordSplit> splits;

  /// Headwords a phrase may be hiding: `picked the phone up` -> `pick up`,
  /// `rufe dich an` -> `anrufen`.
  final List<String> phrases;

  /// Hiragana readings of a katakana word's long vowels: `フーゾク` ->
  /// `ふうぞく`, `トーキョー` -> `とうきょう`.
  final List<String> longVowelReadings;

  const MissingWordSuggestions({
    required this.spellingSuggestions,
    required this.splits,
    this.phrases = const [],
    this.longVowelReadings = const [],
  });

  static const empty = MissingWordSuggestions(
    spellingSuggestions: [],
    splits: [],
    phrases: [],
    longVowelReadings: [],
  );

  bool get isEmpty =>
      spellingSuggestions.isEmpty &&
      splits.isEmpty &&
      phrases.isEmpty &&
      longVowelReadings.isEmpty;
}

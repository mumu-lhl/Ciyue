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

  /// Reads the entries for [words], one per distinct headword, in the order
  /// the headwords first appear.
  ///
  /// [resolvedKeys] lets a caller that already resolved [words] hand over
  /// what it found — the key is the candidate, the value the headword
  /// [resolveExactKey] returned for it — so the read does not resolve the
  /// same spelling twice. Candidates that fold to the same headword
  /// (`word`/`Word`/`WORD`) are read once; different headwords
  /// (`abend`/`Abend`) are each read.
  Future<List<DictionaryEntryData>> readExactEntries(
    Iterable<String> words, {
    Map<String, String>? resolvedKeys,
  });
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

/// One dictionary entry: the headword it is filed under and its content.
///
/// [content] is lazy when the entry is built with [DictionaryEntryData.lazy]:
/// the builder runs only on first access and its result is then cached, so a
/// StarDict entry shown with native widgets never pays for the HTML
/// conversion its WebView sibling would have needed. Entries built with the
/// default constructor already hold their content and never call a builder.
class DictionaryEntryData {
  final String headword;

  /// Content already computed at construction, or null when it is built
  /// lazily by [_buildContent].
  final String? _content;

  /// Builds [content] on first access; null when the content is already
  /// held in [_content]. The builder is wrapped to memoize, so repeated
  /// reads return the same string without converting again.
  final String Function()? _buildContent;

  // The parameter name is the public API (`content:`); the field holds it
  // under a private name so the `content` getter can serve both constructors.
  const DictionaryEntryData({required this.headword, required String content})
    : _content = content, // ignore: prefer_initializing_formals
      _buildContent = null;

  DictionaryEntryData.lazy({
    required this.headword,
    required String Function() buildContent,
  }) : _content = null,
       _buildContent = _memoizeBuilder(buildContent);

  /// The entry content, converted on first access when built lazily.
  String get content => _content ?? _buildContent!();

  static String Function() _memoizeBuilder(String Function() buildContent) {
    String? cached;
    return () => cached ??= buildContent();
  }
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

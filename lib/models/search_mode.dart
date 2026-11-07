/// How the search bar matches what the user typed against headwords.
///
/// Lives in `models` instead of `repositories/settings.dart` on purpose:
/// [DictionaryLookup] and the full-text service need the type, and importing
/// settings there would construct the process-wide [Settings] singleton —
/// which reads `prefs` — at import time, breaking plain unit tests that
/// never initialise preferences.
enum SearchMode {
  /// Headwords starting with the query (the historical behaviour).
  prefix,

  /// Headwords ending with the query, served by the reversed-headword
  /// column of the full-text index.
  suffix,

  /// Headwords containing every character/word of the query, served by a
  /// headword-column-qualified FTS5 `MATCH`.
  multiWord,

  /// Matches inside definitions, served by the full-text index.
  fullText,
}

extension SearchModeCycle on SearchMode {
  /// The next mode, wrapping around; the search bar's button cycles in
  /// this order.
  SearchMode get next =>
      SearchMode.values[(index + 1) % SearchMode.values.length];
}

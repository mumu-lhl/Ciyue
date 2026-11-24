import "dart:async";

import "package:ciyue/models/search_mode.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/services/dictionary_lookup_instance.dart";
import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search.dart";
import "package:ciyue/services/full_text_search_service.dart";
import "package:flutter/foundation.dart";

/// One row of the pane's headword list.
class HeadwordPaneRow {
  const HeadwordPaneRow(this.headword, [this.snippet]);

  final String headword;

  /// Definition excerpt, only for [SearchMode.fullText], where the match is
  /// inside the entry rather than on its headword.
  final String? snippet;
}

/// The live headword list of the split view's left pane.
///
/// It answers the same question as the suggestion overlay, but for a list the
/// reader scrolls rather than a dropdown they pick from: a larger
/// per-dictionary limit, and, for the full-text modes, the order a printed
/// dictionary uses instead of relevance.
class HeadwordPaneModel extends ChangeNotifier {
  HeadwordPaneModel({DictionaryLookup? lookup})
    : _lookup = lookup ?? dictionaryLookup;

  /// How many rows one dictionary may contribute.
  ///
  /// Ten dictionaries at this cap cost well under a millisecond to search and
  /// merge; the number is about how many rows are worth reading, not about
  /// what the search can afford.
  static const limit = 200;

  /// Long enough to swallow a burst of keystrokes, short enough that the list
  /// keeps up with typing.
  static const debounce = Duration(milliseconds: 150);

  final DictionaryLookup _lookup;

  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  String _text = "";
  SearchMode _mode = SearchMode.prefix;
  List<HeadwordPaneRow> _rows = const [];
  FullTextIndexStatus _indexStatus = FullTextIndexStatus.ready;

  /// The text the rows belong to, trimmed.
  String get text => _text;

  SearchMode get mode => _mode;

  List<HeadwordPaneRow> get rows => _rows;

  /// Worst index status across the dictionaries, for the modes that need the
  /// full-text index. Always [FullTextIndexStatus.ready] in prefix mode.
  FullTextIndexStatus get indexStatus => _indexStatus;

  /// Whether the pane should show history instead of the list.
  bool get isEmpty => _text.isEmpty;

  /// Re-runs the list for [text] once the debounce expires.
  ///
  /// [mode] is captured with the query: switching the mode reports the same
  /// text again, and an answer for the old mode must not paint over the new
  /// one.
  void update(
    String text, {
    required SearchMode mode,
    FullTextSearchService? fullText,
  }) {
    _text = text.trim();
    _mode = mode;
    _timer?.cancel();
    final generation = ++_generation;
    if (_text.isEmpty) {
      _rows = const [];
      _indexStatus = FullTextIndexStatus.ready;
      notifyListeners();
      return;
    }
    _timer = Timer(
      debounce,
      () => unawaited(_run(_text, mode, fullText, generation)),
    );
  }

  Future<void> _run(
    String query,
    SearchMode mode,
    FullTextSearchService? fullText,
    int generation,
  ) async {
    DictionarySearchSuggestions suggestions;
    try {
      suggestions = await _lookup.searchSuggestions(
        query,
        mode: mode,
        fullText: fullText,
        limit: limit,
        browseOrder: true,
      );
    } catch (_) {
      // A broken dictionary contributes nothing instead of emptying the pane:
      // the previous rows stay until a query answers something.
      return;
    }
    if (_disposed || generation != _generation) return;
    _rows = mode == SearchMode.fullText
        ? [
            for (final hit in suggestions.fullTextHits)
              HeadwordPaneRow(hit.headword, _snippetText(hit)),
          ]
        : [
            for (final headword in suggestions.dictionarySuggestions)
              HeadwordPaneRow(headword),
          ];
    _indexStatus = suggestions.fullTextIndexStatus;
    notifyListeners();
  }

  static String _snippetText(FullTextHit hit) =>
      parseSnippet(hit.snippet).map((segment) => segment.text).join();

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

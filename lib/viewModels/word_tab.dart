import "package:flutter/foundation.dart";

@immutable
class WordTabEntry {
  final String word;
  final int? dictId;

  const WordTabEntry({required this.word, this.dictId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordTabEntry &&
          runtimeType == other.runtimeType &&
          word == other.word &&
          dictId == other.dictId;

  @override
  int get hashCode => Object.hash(word, dictId);

  @override
  String toString() => "WordTabEntry(word: $word, dictId: $dictId)";
}

class WordTab {
  final String id;
  final List<WordTabEntry> _history;
  int _historyIndex;

  WordTab({
    String? id,
    List<WordTabEntry>? initialHistory,
    int initialIndex = 0,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       _history = initialHistory != null && initialHistory.isNotEmpty
           ? List<WordTabEntry>.from(initialHistory)
           : <WordTabEntry>[const WordTabEntry(word: "")],
       _historyIndex = initialIndex;

  List<WordTabEntry> get history => List.unmodifiable(_history);
  int get historyIndex => _historyIndex;

  String get currentWord =>
      _historyIndex >= 0 && _historyIndex < _history.length
      ? _history[_historyIndex].word
      : "";

  int? get currentDictId =>
      _historyIndex >= 0 && _historyIndex < _history.length
      ? _history[_historyIndex].dictId
      : null;

  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward => _historyIndex < _history.length - 1;

  void navigateTo(String word, {int? dictId}) {
    final trimmed = word.trim();
    if (_historyIndex >= 0 &&
        _historyIndex < _history.length &&
        currentWord == trimmed &&
        currentDictId == dictId) {
      return;
    }

    // If current entry is blank (e.g. from new empty tab), overwrite it
    if (_history.length == 1 && _history[0].word.isEmpty) {
      _history[0] = WordTabEntry(word: trimmed, dictId: dictId);
      _historyIndex = 0;
      return;
    }

    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(WordTabEntry(word: trimmed, dictId: dictId));
    _historyIndex = _history.length - 1;
  }

  bool goBack() {
    if (canGoBack) {
      _historyIndex--;
      return true;
    }
    return false;
  }

  bool goForward() {
    if (canGoForward) {
      _historyIndex++;
      return true;
    }
    return false;
  }
}

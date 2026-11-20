import "package:material_ui/material_ui.dart";

/// Context passed to `/word/:word` when browsing words within a list (e.g. Wordbook).
class WordListContext {
  final List<String> words;
  final int initialIndex;

  const WordListContext({required this.words, required this.initialIndex});
}

class WordPagerInfo {
  final int currentIndex;
  final int totalCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const WordPagerInfo({
    required this.currentIndex,
    required this.totalCount,
    this.onPrevious,
    this.onNext,
  });
}

import "package:ciyue/repositories/open_records.dart";
import "package:ciyue/ui/core/word_display/pager_context.dart";
import "package:ciyue/ui/core/word_display/word_display.dart";
import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

/// A pager widget that displays words from a list with horizontal swipe navigation,
/// desktop prev/next controls, and keyboard arrow shortcut support.
class WordDisplayPager extends StatefulWidget {
  final List<String> words;
  final int initialIndex;

  const WordDisplayPager({
    super.key,
    required this.words,
    required this.initialIndex,
  });

  @override
  State<WordDisplayPager> createState() => _WordDisplayPagerState();
}

class _WordDisplayPagerState extends State<WordDisplayPager> {
  late final PageController _pageController;
  late int _currentIndex;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.words.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _recordHistory(_currentIndex);
  }

  void _recordHistory(int index) {
    if (index >= 0 && index < widget.words.length) {
      final word = widget.words[index];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Provider.of<OpenRecordsRepository>(context, listen: false).add(word);
      });
    }
  }

  void _previousWord() {
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
      return;
    }
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextWord() {
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
      return;
    }
    if (_currentIndex < widget.words.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _previousWord,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _nextWord,
      },
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.words.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            _recordHistory(index);
          },
          itemBuilder: (context, index) {
            final word = widget.words[index];
            return WordDisplay(
              key: ValueKey("word_page_$word"),
              word: word,
              pagerInfo: WordPagerInfo(
                currentIndex: index,
                totalCount: widget.words.length,
                onPrevious: index > 0 ? _previousWord : null,
                onNext: index < widget.words.length - 1 ? _nextWord : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup_instance.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

class WordSearchBarWithSuggestions extends ConsumerStatefulWidget {
  final String word;
  final SearchController? controller;
  final FocusNode? focusNode;
  final bool isHome;
  final bool autoFocus;
  final ValueChanged<String>? onWordSelected;

  const WordSearchBarWithSuggestions({
    super.key,
    required this.word,
    this.controller,
    this.focusNode,
    this.isHome = false,
    this.autoFocus = false,
    this.onWordSelected,
  });

  @override
  ConsumerState<WordSearchBarWithSuggestions> createState() =>
      _WordSearchBarWithSuggestionsState();
}

class _WordSearchBarWithSuggestionsState
    extends ConsumerState<WordSearchBarWithSuggestions> {
  SearchController? _anchorController;

  /// Monotonic id for suggestion requests. Lets superseded keystrokes and
  /// out-of-order query results discard themselves instead of firing
  /// redundant dictionary lookups.
  int _suggestionGen = 0;

  /// Last successfully built suggestions, returned as-is when a keystroke
  /// is superseded mid-debounce so the list doesn't flicker.
  List<Widget>? _lastSuggestions;

  static const _suggestionDebounce = Duration(milliseconds: 100);

  SearchController? get _effectiveController =>
      widget.controller ?? _anchorController;

  bool get _isViewOpen =>
      _effectiveController != null &&
      _effectiveController!.isAttached &&
      _effectiveController!.isOpen;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null && !_isViewOpen) {
      widget.controller!.text = widget.word;
    }
  }

  @override
  void didUpdateWidget(covariant WordSearchBarWithSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        widget.word != oldWidget.word &&
        !_isViewOpen) {
      widget.controller!.text = widget.word;
    }
  }

  void _selectAllText(SearchController controller) {
    if (controller.text.isNotEmpty) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    }
  }

  void _openWord(SearchController controller, String word) {
    final normalizedWord = word.trim();
    if (normalizedWord.isEmpty) return;

    ref.read(historyModelProvider).addHistory(normalizedWord);
    if (controller.isAttached && controller.isOpen) {
      controller.closeView(normalizedWord);
    }
    if (widget.isHome && settings.autoRemoveSearchWord) {
      controller.text = "";
    }
    if (widget.onWordSelected != null) {
      widget.onWordSelected!(normalizedWord);
    } else {
      final location = GoRouterState.of(context).uri.toString();
      final target = "/word/${Uri.encodeComponent(normalizedWord)}";
      // Sync tab history so back/forward buttons work (the tab system and
      // router system were out of sync).
      try {
        ref.read(homeModelProvider).navigateInCurrentTab(normalizedWord);
      } catch (_) {}
      // If already on a word page, replace instead of pushing to avoid
      // accumulating a deep stack of word pages (user reported: hard to
      // go back to home after many lookups).
      if (location.startsWith("/word/")) {
        context.go(target);
      } else {
        context.push(target);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SearchAnchor(
          viewHintText: AppLocalizations.of(context)!.search,
          viewOnOpen: () {
            final ctrl = _effectiveController;
            if (ctrl == null) return;
            if (widget.word.isNotEmpty && !widget.isHome) {
              _selectAllText(ctrl);
            } else {
              ctrl.selection = TextSelection.collapsed(
                offset: ctrl.text.length,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctrl.isAttached) {
                  ctrl.selection = TextSelection.collapsed(
                    offset: ctrl.text.length,
                  );
                }
              });
            }
          },
          viewOnClose: () {
            final ctrl = _effectiveController;
            if (ctrl != null && widget.word.isNotEmpty && !widget.isHome) {
              ctrl.text = widget.word;
            }
          },
          builder: (context, controller) {
            _anchorController = controller;
            if (widget.controller == null &&
                widget.word.isNotEmpty &&
                controller.text.isEmpty &&
                !_isViewOpen) {
              controller.text = widget.word;
            }
            return SearchBar(
              autoFocus: widget.autoFocus,
              focusNode: widget.focusNode,
              controller: controller,
              hintText: AppLocalizations.of(context)!.search,
              constraints: const BoxConstraints(
                maxHeight: 42,
                minHeight: 42,
                maxWidth: 500,
              ),
              onTap: () {
                if (controller.text.isNotEmpty && !widget.isHome) {
                  _selectAllText(controller);
                }
                controller.openView();
              },
              onChanged: (_) {
                if (!_isViewOpen) {
                  controller.openView();
                }
                controller.selection = TextSelection.collapsed(
                  offset: controller.text.length,
                );
              },
              onSubmitted: (word) => _openWord(controller, word),
              leading: const Icon(Icons.search),
            );
          },
          searchController: widget.controller,
          isFullScreen: !isLargeScreen(context),
          viewOnSubmitted: (String word) {
            final ctrl = _effectiveController;
            if (ctrl != null) {
              _openWord(ctrl, word);
            }
          },
          suggestionsBuilder:
              (BuildContext context, SearchController controller) async {
                List<Widget> keepPrevious() =>
                    _lastSuggestions ?? const <Widget>[];

                final searchWord = controller.text.trim();
                final gen = ++_suggestionGen;

                // Debounce: only the last keystroke of a burst runs the
                // query. Superseded calls return the previous suggestions.
                await Future.delayed(_suggestionDebounce);
                if (!mounted) return keepPrevious();
                if (gen != _suggestionGen ||
                    controller.text.trim() != searchWord) {
                  return keepPrevious();
                }

                while (ref.read(dictManagerModelProvider).isSwitchingGroup) {
                  await Future.delayed(const Duration(milliseconds: 40));
                  if (!mounted) return keepPrevious();
                }

                if (searchWord.isEmpty) {
                  _lastSuggestions = [const SizedBox.shrink()];
                  return _lastSuggestions!;
                }

                final suggestions = await dictionaryLookup.searchSuggestions(
                  searchWord,
                );
                if (!context.mounted || gen != _suggestionGen) {
                  // A newer keystroke arrived while querying: drop the stale
                  // result instead of overwriting fresh suggestions.
                  return keepPrevious();
                }
                final l10n = AppLocalizations.of(context)!;

                ListTile buildSuggestionTile(String word) {
                  return ListTile(
                    title: Text(word),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      if (!context.mounted) return;
                      _openWord(controller, word);
                    },
                  );
                }

                _lastSuggestions = [
                  if (settings.aiExplainWord) buildSuggestionTile(searchWord),
                  ...suggestions.dictionarySuggestions.map(buildSuggestionTile),
                  if (suggestions.spellingSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 16,
                        top: 10,
                        bottom: 5,
                      ),
                      child: Text(
                        l10n.spellingSuggestions,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ...suggestions.spellingSuggestions.map(buildSuggestionTile),
                ];
                return _lastSuggestions!;
              },
        ),
      ),
    );
  }
}

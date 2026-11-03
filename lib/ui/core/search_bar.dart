import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup_instance.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

/// Selects the whole text in the field that owns [focusNode].
///
/// The search bar renders its own text editing controller, and the
/// [SearchController] only carries the text along: setting its selection
/// never reaches the field. The selection therefore has to go through the
/// field itself.
void selectAllTextInField(FocusNode focusNode) {
  final context = focusNode.context;
  if (context == null) return;
  final controller = context
      .findAncestorWidgetOfExactType<EditableText>()
      ?.controller;
  if (controller == null) return;
  if (controller.text.isEmpty) return;
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );
}

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

  /// Captured during a synchronous build.
  ///
  /// The suggestion builders below run after an `await`, and a submitted word
  /// replaces the page they belong to. Looking an inherited widget up on the
  /// state's context at that point registers a dependency on a tree that is
  /// being torn down, which trips the framework's `_dependents.isEmpty`
  /// assertion. Reading the cached values instead never touches the tree.
  AppLocalizations? _l10n;
  ThemeData? _theme;

  /// Suppresses the automatic opening right after a close.
  ///
  /// The anchor restores the focus to this box when its view is dismissed, and
  /// `isOpen` still reads `false` at that point, so the focus listener would
  /// reopen the view immediately: closing it with Esc looked like it did
  /// nothing. A tap opens the view through the anchor itself, so the listener
  /// is not needed for that.
  bool _ignoreNextFocusOpen = false;

  /// Ends the suppression above. Kept as a timer so that [dispose] can cancel
  /// it: a callback that outlives the state leaves a pending timer behind,
  /// which the test binding treats as a failure.
  Timer? _reopenSuppression;

  static const _suggestionDebounce = Duration(milliseconds: 100);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context);
    _theme = Theme.of(context);
  }

  SearchController? get _effectiveController =>
      widget.controller ?? _anchorController;

  bool get _isViewOpen =>
      _effectiveController != null &&
      _effectiveController!.isAttached &&
      _effectiveController!.isOpen;

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(_onFocusChanged);
    if (widget.controller != null && !_isViewOpen) {
      widget.controller!.text = widget.word;
    }
  }

  @override
  void didUpdateWidget(covariant WordSearchBarWithSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      widget.focusNode?.addListener(_onFocusChanged);
    }
    if (widget.controller != null &&
        widget.word != oldWidget.word &&
        !_isViewOpen) {
      widget.controller!.text = widget.word;
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChanged);
    // The globals must not outlive the box they point at: a page that is
    // gone would leave Esc handing the focus to a node that is already
    // disposed, and touching such a node is an assertion failure.
    if (identical(activeSearchFocusNode, widget.focusNode)) {
      activeSearchFocusNode = null;
    }
    final controller = _effectiveController;
    if (controller != null && identical(activeSearchController, controller)) {
      activeSearchController = null;
      searchSuggestionViewOpen = false;
    }
    _reopenSuppression?.cancel();
    super.dispose();
  }

  /// Remembers this box as the one Esc hands the focus to and from.
  void _markActive() {
    final node = widget.focusNode;
    if (node != null) activeSearchFocusNode = node;
    final controller = _effectiveController;
    if (controller != null) activeSearchController = controller;
  }

  void _onFocusChanged() {
    final node = widget.focusNode;
    if (node == null || !node.hasFocus) return;
    activeSearchFocusNode = node;
    final controller = _effectiveController;
    if (controller != null) activeSearchController = controller;
    // The entry's own box is where the reader comes to when they want to
    // look up another word, so it opens as soon as it takes the focus: the
    // text they type has to land where they can see it. The box of the home
    // page keeps its own behaviour and only opens when it is tapped.
    if (!widget.isHome &&
        controller != null &&
        !controller.isOpen &&
        !_ignoreNextFocusOpen) {
      controller.openView();
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
    // `isOpen` lags behind the view, so the flag the anchor reports is the one
    // that tells whether there is a list to close.
    if (searchSuggestionViewOpen ||
        (controller.isAttached && controller.isOpen)) {
      searchSuggestionViewOpen = false;
      if (controller.isAttached) controller.closeView(normalizedWord);
    }
    // Drop the field focus as well: on Android the IME turns a physical Esc
    // into BACK while it is up, so the key would never reach the app, and
    // leaving the field focused keeps the keyboard on screen after a lookup.
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.isHome && settings.autoRemoveSearchWord) {
      controller.text = "";
    }
    if (widget.onWordSelected != null) {
      widget.onWordSelected!(normalizedWord);
    } else {
      final location = GoRouterState.of(context).uri.toString();
      final target = "/word/${Uri.encodeComponent(normalizedWord)}";
      // Both the tab bookkeeping and the navigation wait for the next frame.
      // Submitting the field has already closed the anchor's view, and either
      // rebuilding the page that owns it (the history update notifies) or
      // replacing that page (the route change) inside the same frame
      // deactivates the view's inherited scope while its dependents are still
      // attached, which trips the framework's `_dependents.isEmpty`
      // assertion.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Sync tab history so back/forward buttons work (the tab system and
        // router system were out of sync).
        try {
          ref.read(homeModelProvider).navigateInCurrentTab(normalizedWord);
        } catch (_) {}
        // A pushed entry page follows the tab's current word and swaps the
        // entry in place, so it needs no navigation at all; replacing its
        // route would rebuild the page that owns this search box. Only a
        // lookup made from the home page has to open a page.
        if (!location.startsWith("/word/")) {
          context.push(target);
        }
      });
    }

    // The lookup is done: hand the focus to the entry, so the next Esc reaches
    // the app through the WebView instead of dying in the IME.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusActiveEntrySoon();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SearchAnchor(
          viewHintText: AppLocalizations.of(context)!.search,
          viewOnOpen: () {
            _markActive();
            searchSuggestionViewOpen = true;
            // Widgets cached for the previous view belong to a tree that is
            // no longer there; rebuild them instead of reusing the elements.
            _lastSuggestions = null;
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
            searchSuggestionViewOpen = false;
            _ignoreNextFocusOpen = true;
            _reopenSuppression?.cancel();
            _reopenSuppression = Timer(const Duration(milliseconds: 400), () {
              _ignoreNextFocusOpen = false;
            });
            final ctrl = _effectiveController;
            // Only fill in a word when there is nothing to lose: a box the
            // reader was halfway through filling must keep what they typed.
            if (ctrl != null &&
                ctrl.text.trim().isEmpty &&
                widget.word.isNotEmpty &&
                !widget.isHome) {
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
                _markActive();
                if (controller.text.isNotEmpty && !widget.isHome) {
                  _selectAllText(controller);
                }
                controller.openView();
              },
              onChanged: (_) {
                _markActive();
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
          suggestionsBuilder: (BuildContext context, SearchController controller) async {
            // Once the anchor's view is gone, handing the cached widgets back
            // re-inserts elements that belonged to the torn-down tree and
            // trips the framework's `_dependents.isEmpty` assertion. An empty
            // list is the safe answer at that point.
            List<Widget> keepPrevious() => controller.isOpen
                ? (_lastSuggestions ?? const <Widget>[])
                : const <Widget>[];

            final searchWord = controller.text.trim();
            final gen = ++_suggestionGen;

            // Debounce: only the last keystroke of a burst runs the
            // query. Superseded calls return the previous suggestions.
            await Future.delayed(_suggestionDebounce);
            if (!mounted) return keepPrevious();
            if (gen != _suggestionGen || controller.text.trim() != searchWord) {
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
            // The `context` handed to this builder belongs to the view the
            // anchor opens, and a submitted word closes that view. Its element
            // stays mounted after that, so asking it for an inherited widget
            // throws; this state is the one that knows whether it is still in
            // the tree, and it survives the view closing.
            if (!mounted || gen != _suggestionGen) {
              // A newer keystroke arrived while querying: drop the stale
              // result instead of overwriting fresh suggestions.
              return keepPrevious();
            }
            final l10n = _l10n;
            final theme = _theme;
            if (l10n == null) return keepPrevious();

            ListTile buildSuggestionTile(String word) {
              return ListTile(
                title: Text(word),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  if (!mounted) return;
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
                    style: theme?.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ...suggestions.spellingSuggestions.map(buildSuggestionTile),
              ListTile(
                leading: const Icon(Icons.find_in_page),
                title: Text(l10n.searchInDefinitions(searchWord)),
                onTap: () {
                  if (!mounted) return;
                  controller.closeView(searchWord);
                  this.context.push(
                    "/full-text-search?query=${Uri.encodeQueryComponent(searchWord)}",
                  );
                },
              ),
            ];
            return _lastSuggestions!;
          },
        ),
      ),
    );
  }
}

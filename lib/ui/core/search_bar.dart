import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/search_mode.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup_instance.dart";
import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search.dart";
import "package:ciyue/services/full_text_search_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

/// Icon for each search mode, shown on the search bar's cycling button.
IconData _searchModeIcon(SearchMode mode) => switch (mode) {
  SearchMode.prefix => Icons.sort_by_alpha,
  SearchMode.suffix => Icons.vertical_align_bottom,
  SearchMode.multiWord => Icons.link,
  SearchMode.fullText => Icons.find_in_page,
};

/// Localised label for each search mode, used in the button tooltip.
String _searchModeLabel(AppLocalizations l10n, SearchMode mode) =>
    switch (mode) {
      SearchMode.prefix => l10n.searchModePrefix,
      SearchMode.suffix => l10n.searchModeSuffix,
      SearchMode.multiWord => l10n.searchModeMultiWord,
      SearchMode.fullText => l10n.searchModeFullText,
    };

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

  /// Dictionaries this bar already asked to build an index for, so a
  /// failed build is retried only from the full-text page, not on every
  /// keystroke in a mode that needs the index.
  final Set<int> _ftsBuildsStarted = {};

  /// Sorted ids of the dictionaries whose index is ready, as last seen in
  /// [build]. When the set changes while the suggestion view is open in a
  /// mode that needs the index, the view re-runs so fresh results appear.
  String? _lastFtsReadyKey;

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

  /// Re-runs the suggestion list for the current text and mode.
  ///
  /// Bumps [_suggestionGen] first so in-flight results from the old mode
  /// or query discard themselves in the generation guard. Closes and
  /// reopens the view when it is open: the anchor only runs
  /// `suggestionsBuilder` on open or text change, so this is the only way
  /// to refresh it. No-op when the view is closed.
  void _refreshSuggestionsView() {
    final controller = _effectiveController;
    if (controller == null || !mounted) return;
    _suggestionGen++;
    if (!controller.isAttached || !controller.isOpen) return;
    final text = controller.text;
    controller.closeView(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.isAttached) {
        controller.openView();
      }
    });
  }

  /// Advances the search mode and refreshes the open suggestion view so
  /// it shows the new mode's results instead of the old mode's.
  Future<void> _cycleSearchMode(SearchController controller) async {
    await settings.setSearchMode(settings.searchMode.next);
    _refreshSuggestionsView();
  }

  /// Starts index builds for dictionaries that have none, for the modes
  /// that need the index. A failed build is not retried here: the
  /// full-text page owns the retry button.
  ///
  /// Dictionaries stamped ready get a fingerprint check too: a meta row
  /// that still says ready after a schema change (or a replaced
  /// dictionary file) is stale, and `ensureBuilt` is the only place the
  /// fingerprint is compared — without this, a stale index in a group
  /// that was not current at reconcile time would keep serving queries
  /// its tables cannot run. The check is one meta read when current;
  /// only a stale fingerprint starts a rebuild. Once checked, the
  /// dictionary is not re-checked here, so a failed rebuild is not
  /// retried on every keystroke.
  void _maybeStartFtsBuilds() {
    final service = ref.read(fullTextSearchServiceProvider);
    for (final dictionary in [
      for (final id in dictManager.dictIds) dictManager.dicts[id],
    ].whereType<LoadedDictionary>()) {
      if (_ftsBuildsStarted.contains(dictionary.id)) continue;
      final status = service.stateFor(dictionary.id).status;
      if (status != FullTextIndexStatus.notBuilt &&
          status != FullTextIndexStatus.ready) {
        continue;
      }
      _ftsBuildsStarted.add(dictionary.id);
      unawaited(service.ensureBuilt(dictionary));
    }
  }

  /// Closes the suggestion view and opens the full-text page with the
  /// current query, which is where index builds run and report progress.
  void _openFullTextPage(SearchController controller, String query) {
    if (!mounted) return;
    controller.closeView(query);
    context.push("/full-text-search?query=${Uri.encodeQueryComponent(query)}");
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
    final searchMode = ref.watch(
      settingsProvider.select((settings) => settings.searchMode),
    );
    // Re-run the suggestions when an index build finishes while the view
    // is open in a mode that needs the index. Only the ready set matters:
    // per-batch progress notifies must not refresh the view, so the key is
    // the sorted ready ids, not the progress values.
    final ftsService = ref.watch(fullTextSearchServiceProvider);
    final readyKey =
        (ftsService.states.entries
                .where(
                  (entry) => entry.value.status == FullTextIndexStatus.ready,
                )
                .map((entry) => entry.key)
                .toList()
              ..sort())
            .join(",");
    if (_lastFtsReadyKey != readyKey) {
      final hadPrevious = _lastFtsReadyKey != null;
      _lastFtsReadyKey = readyKey;
      if (hadPrevious && searchMode != SearchMode.prefix && _isViewOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshSuggestionsView();
        });
      }
    }
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
              // The bar is 42px high and ~500 wide, so there is no room
              // for a dropdown: one small button cycles prefix -> suffix
              // -> multi-word -> full text. Submitting still opens the
              // exact headword in every mode.
              trailing: [
                IconButton(
                  icon: Icon(_searchModeIcon(searchMode)),
                  tooltip: AppLocalizations.of(context)!.searchModeTooltip(
                    _searchModeLabel(AppLocalizations.of(context)!, searchMode),
                  ),
                  onPressed: () => _cycleSearchMode(controller),
                ),
              ],
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
            // The race guard captures the query AND the mode: an in-flight
            // FTS query from the old mode must not paint its results after
            // a mode switch, and vice versa.
            final mode = settings.searchMode;
            final gen = ++_suggestionGen;

            // Debounce: only the last keystroke of a burst runs the
            // query. Superseded calls return the previous suggestions.
            await Future.delayed(_suggestionDebounce);
            if (!mounted) return keepPrevious();
            if (gen != _suggestionGen ||
                settings.searchMode != mode ||
                controller.text.trim() != searchWord) {
              return keepPrevious();
            }

            while (ref.read(dictManagerModelProvider).isSwitchingGroup) {
              await Future.delayed(const Duration(milliseconds: 40));
              if (!mounted) return keepPrevious();
              if (gen != _suggestionGen || settings.searchMode != mode) {
                return keepPrevious();
              }
            }

            if (searchWord.isEmpty) {
              _lastSuggestions = [const SizedBox.shrink()];
              return _lastSuggestions!;
            }

            // The modes that need the index start its build on first use,
            // like the full-text page does, instead of sitting on "not
            // built" until the user opens that page.
            if (mode != SearchMode.prefix) {
              _maybeStartFtsBuilds();
            }

            final suggestions = await dictionaryLookup.searchSuggestions(
              searchWord,
              mode: mode,
              fullText: ref.read(fullTextSearchServiceProvider),
            );
            // The `context` handed to this builder belongs to the view the
            // anchor opens, and a submitted word closes that view. Its element
            // stays mounted after that, so asking it for an inherited widget
            // throws; this state is the one that knows whether it is still in
            // the tree, and it survives the view closing.
            if (!mounted ||
                gen != _suggestionGen ||
                settings.searchMode != mode) {
              // A newer keystroke arrived while querying, or the mode
              // changed: drop the stale result instead of overwriting
              // fresh suggestions.
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

            ListTile buildFullTextTile(FullTextHit hit) {
              return ListTile(
                title: Text(hit.headword),
                subtitle: Text(
                  parseSnippet(hit.snippet).map((s) => s.text).join(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  if (!mounted) return;
                  _openWord(controller, hit.headword);
                },
              );
            }

            // The modes that need the index never fail silently: when an
            // index is unbuilt, building or failed, the bar says so up
            // front and offers the full-text page, where the build runs
            // and reports progress.
            ListTile? buildIndexStatusTile() {
              if (mode == SearchMode.prefix) return null;
              switch (suggestions.fullTextIndexStatus) {
                case FullTextIndexStatus.ready:
                  return null;
                case FullTextIndexStatus.building:
                  return ListTile(
                    leading: const Icon(Icons.hourglass_top),
                    title: Text(l10n.buildingFullTextIndex),
                    onTap: () => _openFullTextPage(controller, searchWord),
                  );
                case FullTextIndexStatus.failed:
                  return ListTile(
                    leading: const Icon(Icons.warning),
                    title: Text(l10n.fullTextIndexFailed),
                    onTap: () => _openFullTextPage(controller, searchWord),
                  );
                case FullTextIndexStatus.notBuilt:
                  return ListTile(
                    leading: const Icon(Icons.hourglass_top),
                    title: Text(l10n.searchModeIndexNotBuilt),
                    onTap: () => _openFullTextPage(controller, searchWord),
                  );
              }
            }

            final statusTile = buildIndexStatusTile();
            final statusTiles = statusTile == null
                ? null
                : <Widget>[statusTile];
            _lastSuggestions = [
              ...?statusTiles,
              if (mode == SearchMode.fullText)
                ...suggestions.fullTextHits.map(buildFullTextTile)
              else ...[
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
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ),
                ...suggestions.spellingSuggestions.map(buildSuggestionTile),
              ],
              ListTile(
                leading: const Icon(Icons.find_in_page),
                title: Text(l10n.searchInDefinitions(searchWord)),
                onTap: () {
                  if (!mounted) return;
                  _openFullTextPage(controller, searchWord);
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

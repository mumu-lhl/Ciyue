import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/floating_window.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/ai_widgets.dart";
import "package:ciyue/ui/core/word_display/audio_waveform.dart";
import "package:ciyue/ui/core/word_display/buttons.dart";
import "package:ciyue/ui/core/word_display/expansion_display.dart";
import "package:ciyue/ui/core/word_display/missing_word_suggestions.dart";
import "package:ciyue/ui/core/word_display/pager_context.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:ciyue/ui/pages/main/home/app_bar.dart" show GroupSelectorButton;
import "package:ciyue/ui/pages/main/home/shortcuts.dart";
import "package:ciyue/utils.dart" as app_utils;
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

class WordDisplay extends ConsumerStatefulWidget {
  final String word;
  final WordPagerInfo? pagerInfo;
  final int? initialDictId;
  final bool showBackButton;
  final Widget? bottomNavigationBar;

  const WordDisplay({
    super.key,
    required this.word,
    this.pagerInfo,
    this.initialDictId,
    this.showBackButton = true,
    this.bottomNavigationBar,
  });

  @override
  ConsumerState<WordDisplay> createState() => _WordDisplayState();
}

class _WordDisplayState extends ConsumerState<WordDisplay> {
  final SearchController _searchController = SearchController();
  List<int>? _lastValidDictIds;

  /// The word on screen.
  ///
  /// A pushed entry page follows the tab's current word, so a lookup swaps the
  /// entry in place instead of replacing the route. Replacing it rebuilds the
  /// page the title search box lives in, and the search anchor that submitted
  /// the word does not survive being torn down that way: the framework trips
  /// its element assertions. The pane inside the home split view keeps taking
  /// the word from its parent, which already follows the selection.
  late String _word;

  /// The tab bar's controller while the tab layout is on screen. Kept so
  /// that [dispose] can tell whether the shared one is still ours.
  TabController? _tabController;
  VoidCallback? _tabListener;

  /// The search box in the title bar, so Esc can move the focus into it and
  /// back to the entry.
  final FocusNode _searchFocusNode = FocusNode();

  Widget? _buildSearchBar(Settings settings) {
    return buildTitle(
      _word,
      settings,
      controller: _searchController,
      focusNode: _searchFocusNode,
      // The home pane already shows the selected word, so a lookup here
      // swaps the current tab instead of pushing a standalone entry page.
      // A pushed word page keeps its own navigation behaviour.
      onWordSelected: widget.showBackButton
          ? null
          : (word) => ref.read(homeModelProvider).selectedWord = word,
    );
  }

  /// Records which dictionary the tab bar is showing.
  ///
  /// The neighbouring tabs stay alive, so "the last WebView created" is not
  /// the one on screen; Esc has to hand the focus to the visible one.
  void _syncActiveEntry(
    TabController controller,
    List<int> validDictIds,
    bool aiExplainWord,
  ) {
    final index = controller.index - (aiExplainWord ? 1 : 0);
    activeEntryDictId = index >= 0 && index < validDictIds.length
        ? validDictIds[index]
        : null;
  }

  /// Readings of a long word as several headwords, phrasal verbs, long vowels
  /// and, once they arrive, Hunspell's spelling corrections.
  ///
  /// The providers are watched separately on purpose: the first three are ready
  /// in milliseconds, while `suggest` takes hundreds, so the page shows them
  /// immediately and fills in spelling suggestions later. Nothing at all is
  /// drawn until one of them has something, which keeps the page looking as it
  /// always did for a word nobody can help with.
  Widget _buildMissingWordSuggestions(BuildContext context) {
    final splits = ref.watch(wordSplitsProvider(_word)).asData?.value;
    final phrases = ref.watch(phraseSuggestionsProvider(_word)).asData?.value;
    final longVowels = ref
        .watch(longVowelSuggestionsProvider(_word))
        .asData
        ?.value;
    final spelling = ref
        .watch(missingWordSpellingSuggestionsProvider(_word))
        .asData
        ?.value;
    if ((splits == null || splits.isEmpty) &&
        (phrases == null || phrases.isEmpty) &&
        (longVowels == null || longVowels.isEmpty) &&
        (spelling == null || spelling.isEmpty)) {
      return const SizedBox.shrink();
    }

    return MissingWordSuggestionsView(
      suggestions: MissingWordSuggestions(
        spellingSuggestions: spelling ?? const [],
        splits: splits ?? const [],
        phrases: phrases ?? const [],
        longVowelReadings: longVowels ?? const [],
      ),
      // The same path a dictionary link takes: it records the word in history
      // and opens it in the current tab, on both layouts.
      onSelected: (word) =>
          handleOpenWordNavigation(context, word, newTab: false),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (runningInFloatingWindow) {
      unawaited(dismissFloatingWindow());
    } else {
      context.go("/");
    }
  }

  @override
  void dispose() {
    if (_tabListener != null) {
      _tabController?.removeListener(_tabListener!);
    }
    // Only clear the shared controller when it is still the one this entry
    // handed over: a newer entry may have taken over already.
    if (identical(dictTabController, _tabController)) {
      dictTabController = null;
    }
    // The node is disposed right below, so the global pointer has to let go
    // of it first: handing the focus to a disposed node is an assertion
    // failure.
    if (identical(pageSearchFocusNode, _searchFocusNode)) {
      pageSearchFocusNode = null;
    }
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A pushed entry page owns its title search box. The pane inside the home
    // split view does not, so the home page's box stays the default there.
    if (widget.showBackButton) {
      pageSearchFocusNode = _searchFocusNode;
    }
    // A pushed entry page follows the tab's current word so a lookup swaps the
    // entry in place. The word-list pager is the exception: each page owns the
    // word it was built with, and following the tab would make every page show
    // whatever the home page last selected.
    final selected = widget.showBackButton && widget.pagerInfo == null
        ? ref.watch(homeModelProvider.select((model) => model.selectedWord))
        : null;
    _word = selected != null && selected.isNotEmpty ? selected : widget.word;
    final settings = ref.watch(settingsProvider);
    // Switching the group reloads every dictionary. Drop the cached lookup
    // and entry HTML so every tab is queried again; otherwise the first tab
    // keeps the empty result cached while the switch was in flight.
    ref.listen(dictManagerModelProvider.select((model) => model.groupId), (
      previous,
      next,
    ) {
      if (previous != null && previous != next) {
        ref.invalidate(dictionaryLookupProvider);
        ref.invalidate(validDictIdsProvider);
        ref.invalidate(wordContentProvider);
      }
    });
    final validDictIdsAsync = ref.watch(validDictIdsProvider(_word));
    if (validDictIdsAsync.hasValue) {
      _lastValidDictIds = validDictIdsAsync.requireValue;
    }

    // Keep the current dictionary view in the tree while checking the next
    // word. The WebView's content provider retains the previous HTML until the
    // new entry arrives; switching to the generic loading scaffold here would
    // dispose the native WPE platform view on every word change.
    final displayedValidDictIdsAsync =
        validDictIdsAsync.isLoading && _lastValidDictIds != null
        ? AsyncData<List<int>>(_lastValidDictIds!)
        : validDictIdsAsync;

    return SearchEscapeCloser(
      focusNode: _searchFocusNode,
      controller: _searchController,
      child: withFloatingWindowBackHandler(
        context,
        displayedValidDictIdsAsync.when(
          data: (validDictIds) {
            if (validDictIds.isEmpty && !settings.aiExplainWord) {
              final searchBar = _buildSearchBar(settings);
              return Scaffold(
                appBar: buildAppBar(context, false, title: searchBar),
                bottomNavigationBar:
                    widget.bottomNavigationBar ??
                    ((!settings.searchBarInAppBar && searchBar != null)
                        ? BottomAppBar(child: searchBar)
                        : null),
                body: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.notFound,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _word,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        _buildMissingWordSuggestions(context),
                      ],
                    ),
                  ),
                ),
              );
            }

            final dictsLength = settings.aiExplainWord
                ? validDictIds.length + 1
                : validDictIds.length;
            final showTab = dictsLength > 1;

            final isDesktopScreen = app_utils.isLargeScreen(context);

            // Keep a single dictionary entry in the same tab/expansion layout it
            // will use if the next word matches more dictionaries.
            if (!showTab && validDictIds.isEmpty) {
              // Only the AI explanation is on screen; there is no entry to
              // hand the focus back to.
              activeEntryDictId = null;
              final searchBar = _buildSearchBar(settings);
              return Scaffold(
                appBar: buildAppBar(
                  context,
                  showTab,
                  title: searchBar,
                  showAIButtons: settings.aiExplainWord,
                ),
                bottomNavigationBar:
                    widget.bottomNavigationBar ??
                    ((!settings.searchBarInAppBar && searchBar != null)
                        ? BottomAppBar(child: searchBar)
                        : null),
                floatingActionButton: isDesktopScreen
                    ? null
                    : Button(
                        word: _word,
                        showAIButtons: settings.aiExplainWord,
                      ),
                body: Stack(
                  children: [
                    settings.aiExplainWord
                        ? AIExplainView(word: _word)
                        : _buildWebView(validDictIds[0]),
                    const Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: FloatingAudioIndicator(),
                    ),
                  ],
                ),
              );
            }

            if (settings.dictionarySwitchStyle == DictionarySwitchStyle.tag) {
              int initialTabIndex = 0;
              if (widget.initialDictId != null) {
                final targetIndex = validDictIds.indexOf(widget.initialDictId!);
                if (targetIndex != -1) {
                  initialTabIndex = settings.aiExplainWord
                      ? targetIndex + 1
                      : targetIndex;
                }
              }

              // Rebuild the tab controller when the group changes: its
              // length changes too, and a reused controller can leave the
              // first page blank after switching back.
              final groupId = ref.watch(dictManagerProvider).groupId;
              return DefaultTabController(
                key: ValueKey("tab_group_$groupId"),
                initialIndex: initialTabIndex,
                length: dictsLength,
                child: Builder(
                  builder: (context) {
                    final tabController = DefaultTabController.of(context);
                    // The shortcut that switches dictionaries lives outside the
                    // entry, so the tab bar hands its controller over.
                    if (!identical(_tabController, tabController)) {
                      if (_tabListener != null) {
                        _tabController?.removeListener(_tabListener!);
                      }
                      _tabController = tabController;
                      _tabListener = () => _syncActiveEntry(
                        tabController,
                        validDictIds,
                        settings.aiExplainWord,
                      );
                      tabController.addListener(_tabListener!);
                    }
                    dictTabController = tabController;
                    _syncActiveEntry(
                      tabController,
                      validDictIds,
                      settings.aiExplainWord,
                    );
                    final searchBar = _buildSearchBar(settings);

                    return ListenableBuilder(
                      listenable: tabController,
                      builder: (context, child) {
                        final isAIExplainTabSelected =
                            settings.aiExplainWord && tabController.index == 0;

                        return Scaffold(
                          appBar: buildAppBar(
                            context,
                            showTab,
                            title: searchBar,
                            showAIButtons: isAIExplainTabSelected,
                          ),
                          bottomNavigationBar: widget.bottomNavigationBar,
                          floatingActionButton: isDesktopScreen
                              ? null
                              : Button(
                                  word: _word,
                                  showAIButtons: isAIExplainTabSelected,
                                ),
                          body: Stack(
                            children: [
                              Column(
                                children: [
                                  Expanded(
                                    child: buildTabView(
                                      context,
                                      validDictIds: validDictIds,
                                    ),
                                  ),
                                  if (settings.tabBarPosition ==
                                          TabBarPosition.bottom &&
                                      showTab)
                                    buildTabBar(context),
                                  if (!settings.searchBarInAppBar &&
                                      searchBar != null)
                                    searchBar,
                                ],
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom:
                                    (settings.tabBarPosition ==
                                            TabBarPosition.bottom &&
                                        showTab)
                                    ? 64
                                    : 16,
                                child: const FloatingAudioIndicator(),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            }

            // The expansion layout has no tab bar. Drop the controller left
            // over from the tab layout so the shortcut cannot switch a tab
            // that is no longer on screen.
            dictTabController = null;
            activeEntryDictId = validDictIds.isNotEmpty
                ? validDictIds.first
                : null;

            return ExpansionWordDisplay(
              word: _word,
              validDictIds: validDictIds,
              searchController: _searchController,
              pagerInfo: widget.pagerInfo,
              showBackButton: widget.showBackButton,
              bottomNavigationBar: widget.bottomNavigationBar,
            );
          },
          loading: () {
            final searchBar = _buildSearchBar(settings);
            final firstLoadedDictId = dictManager.dictIds.firstWhere(
              (id) => dictManager.dicts[id]?.isReady == true,
              orElse: () => -1,
            );
            activeEntryDictId = firstLoadedDictId != -1
                ? firstLoadedDictId
                : null;

            return Scaffold(
              appBar: buildAppBar(context, false, title: searchBar),
              bottomNavigationBar:
                  widget.bottomNavigationBar ??
                  ((!settings.searchBarInAppBar && searchBar != null)
                      ? BottomAppBar(child: searchBar)
                      : null),
              body: firstLoadedDictId != -1
                  ? _buildWebView(firstLoadedDictId)
                  : Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
            );
          },
          error: (err, stack) {
            final searchBar = _buildSearchBar(settings);
            return Scaffold(
              appBar: buildAppBar(context, false, title: searchBar),
              bottomNavigationBar:
                  widget.bottomNavigationBar ??
                  ((!settings.searchBarInAppBar && searchBar != null)
                      ? BottomAppBar(child: searchBar)
                      : null),
              body: Center(
                child: Text(
                  AppLocalizations.of(context)!.errorDetails(err.toString()),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  AppBar buildAppBar(
    BuildContext context,
    bool showTab, {
    Widget? title,
    bool showAIButtons = false,
  }) {
    final settings = ref.watch(settingsProvider);
    final isDesktopScreen = app_utils.isLargeScreen(context);
    final locale = AppLocalizations.of(context)!;
    // Desktop: show browser-like back/forward buttons (mobile has them in
    // the bottom bar). Uses the tab's word history.
    final homeModel = isDesktopScreen ? ref.watch(homeModelProvider) : null;
    return AppBar(
      leading: widget.showBackButton
          ? BackButton(onPressed: () => _goBack(context))
          : null,
      automaticallyImplyLeading: widget.showBackButton,
      title: settings.searchBarInAppBar
          ? (title ?? Text(_word, overflow: TextOverflow.ellipsis))
          : (widget.pagerInfo != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_word, overflow: TextOverflow.ellipsis),
                      Text(
                        "${widget.pagerInfo!.currentIndex + 1} / ${widget.pagerInfo!.totalCount}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Text(_word, overflow: TextOverflow.ellipsis)),
      actions: [
        // The embedded home pane keeps its group switcher in the word tab
        // bar, so drawing another one here would duplicate it. A standalone
        // word page has no tab bar and needs its own switcher.
        if (settings.showSidebarIcon && widget.showBackButton)
          GroupSelectorButton(compact: !isDesktopScreen),
        // Desktop back/forward (mobile has these in the bottom bar).
        if (isDesktopScreen && homeModel != null) ...[
          IconButton(
            tooltip: locale.back,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: homeModel.canGoBack
                ? () => _stepThroughHistory(back: true)
                : null,
          ),
          IconButton(
            tooltip: locale.forward,
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: homeModel.canGoForward
                ? () => _stepThroughHistory(back: false)
                : null,
          ),
        ],
        if (settings.searchBarInAppBar && widget.pagerInfo != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                "${widget.pagerInfo!.currentIndex + 1} / ${widget.pagerInfo!.totalCount}",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (widget.pagerInfo != null) ...[
          IconButton(
            tooltip: locale.previousWord,
            icon: const Icon(Icons.chevron_left),
            onPressed: widget.pagerInfo!.onPrevious,
          ),
          IconButton(
            tooltip: locale.nextWord,
            icon: const Icon(Icons.chevron_right),
            onPressed: widget.pagerInfo!.onNext,
          ),
        ],
        if (isDesktopScreen) ...[
          WordPronounceIconButton(word: _word),
          WordStarIconButton(word: _word),
          if (showAIButtons) ...[
            RefreshAIExplainIconButton(word: _word),
            EditAIExplainIconButton(word: _word),
          ],
        ],
        IconButton(
          // The home top row offers a general chat; this one is scoped to
          // the word on screen, so the tooltip says which.
          tooltip: locale.askAboutWord(_word),
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: () =>
              context.push("/chat?word=${Uri.encodeComponent(_word)}"),
        ),
        IconButton(
          tooltip: locale.copy,
          icon: const Icon(Icons.copy),
          onPressed: () => app_utils.addToClipboard(context, _word),
        ),
      ],
      bottom: (showTab && settings.tabBarPosition == TabBarPosition.top)
          ? buildTabBar(context)
          : null,
    );
  }

  /// Steps the word history of the tab and shows the word it landed on.
  ///
  /// The page renders [_word], which follows the tab's selection, so moving
  /// the index is enough: the entry swaps itself in place.
  void _stepThroughHistory({required bool back}) {
    final homeModel = ref.read(homeModelProvider);
    if (back) {
      homeModel.goBack();
    } else {
      homeModel.goForward();
    }
  }

  PreferredSizeWidget buildTabBar(BuildContext context) {
    final dictManager = ref.watch(dictManagerProvider);
    final settings = ref.watch(settingsProvider);
    final validDictIdsAsync = ref.watch(validDictIdsProvider(_word));

    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: validDictIdsAsync.when(
        data: (validDictIds) => TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            if (settings.aiExplainWord) Tab(text: "AI"),
            for (final id in validDictIds)
              if (dictManager.dicts[id] case final dict?) Tab(text: dict.title),
          ],
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget buildTabView(
    BuildContext context, {
    List<int> validDictIds = const [],
  }) {
    final settings = ref.watch(settingsProvider);
    // Switching the dictionary group reloads every dictionary, and the
    // platform WebView views cannot be reused across that switch — the first
    // one would come back blank. Include the group id in the keys so all
    // entries are rebuilt instead of reusing their old views.
    final groupId = ref.watch(dictManagerProvider).groupId;
    final children = <Widget>[
      if (settings.aiExplainWord)
        KeepAliveWidget(
          key: ValueKey("ai_tab_$groupId"),
          child: AIExplainView(word: _word),
        ),
      for (final id in validDictIds)
        KeepAliveWidget(
          key: ValueKey("dict_${id}_$groupId"),
          child: _buildWebView(id),
        ),
    ];
    return TabBarView(
      physics: widget.pagerInfo != null
          ? const NeverScrollableScrollPhysics()
          : null,
      children: children,
    );
  }

  Widget _buildWebView(int id) {
    return buildWebView(_word, id, false);
  }
}

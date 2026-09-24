import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/floating_window.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/ai_widgets.dart";
import "package:ciyue/ui/core/word_display/audio_waveform.dart";
import "package:ciyue/ui/core/word_display/buttons.dart";
import "package:ciyue/ui/core/word_display/expansion_display.dart";
import "package:ciyue/ui/core/word_display/pager_context.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
import "package:ciyue/utils.dart" as app_utils;
import "package:ciyue/viewModels/ai_explanation.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart" as legacy_provider;

class WordDisplay extends ConsumerStatefulWidget {
  final String word;
  final WordPagerInfo? pagerInfo;

  const WordDisplay({super.key, required this.word, this.pagerInfo});

  @override
  ConsumerState<WordDisplay> createState() => _WordDisplayState();
}

class _WordDisplayState extends ConsumerState<WordDisplay> {
  final SearchController _searchController = SearchController();

  Widget? _buildSearchBar(Settings settings) {
    return buildTitle(widget.word, settings, controller: _searchController);
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final validDictIdsAsync = ref.watch(validDictIdsProvider(widget.word));

    return withFloatingWindowBackHandler(
      context,
      validDictIdsAsync.when(
        data: (validDictIds) {
          if (validDictIds.isEmpty && !settings.aiExplainWord) {
            final searchBar = _buildSearchBar(settings);
            return Scaffold(
              appBar: buildAppBar(context, false, title: searchBar),
              bottomNavigationBar:
                  (!settings.searchBarInAppBar && searchBar != null)
                  ? BottomAppBar(child: searchBar)
                  : null,
              body: Center(
                child: Padding(
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
                        widget.word,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
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

          if (!showTab) {
            final searchBar = _buildSearchBar(settings);
            return legacy_provider.ChangeNotifierProvider(
              create: (_) => AIExplanationModel(),
              child: Scaffold(
                appBar: buildAppBar(context, showTab, title: searchBar),
                bottomNavigationBar:
                    (!settings.searchBarInAppBar && searchBar != null)
                    ? BottomAppBar(child: searchBar)
                    : null,
                floatingActionButton: Button(
                  word: widget.word,
                  showAIButtons: settings.aiExplainWord,
                ),
                body: Stack(
                  children: [
                    settings.aiExplainWord
                        ? AIExplainView(word: widget.word)
                        : _buildWebView(validDictIds[0]),
                    const Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: FloatingAudioIndicator(),
                    ),
                  ],
                ),
              ),
            );
          }

          if (settings.dictionarySwitchStyle == DictionarySwitchStyle.tag) {
            return legacy_provider.ChangeNotifierProvider(
              create: (_) => AIExplanationModel(),
              child: DefaultTabController(
                initialIndex: 0,
                length: dictsLength,
                child: Builder(
                  builder: (context) {
                    final tabController = DefaultTabController.of(context);
                    final searchBar = _buildSearchBar(settings);

                    return Scaffold(
                      appBar: buildAppBar(context, showTab, title: searchBar),
                      floatingActionButton: ListenableBuilder(
                        listenable: tabController,
                        builder: (context, child) {
                          final isAIExplainTabSelected =
                              settings.aiExplainWord &&
                              tabController.index == 0;
                          return Button(
                            word: widget.word,
                            showAIButtons: isAIExplainTabSelected,
                          );
                        },
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
                ),
              ),
            );
          }

          return legacy_provider.ChangeNotifierProvider(
            create: (_) => AIExplanationModel(),
            child: ExpansionWordDisplay(
              word: widget.word,
              validDictIds: validDictIds,
              searchController: _searchController,
              pagerInfo: widget.pagerInfo,
            ),
          );
        },
        loading: () {
          final searchBar = _buildSearchBar(settings);
          final firstLoadedDictId = dictManager.dictIds.firstWhere(
            (id) => dictManager.dicts[id]?.isReady == true,
            orElse: () => -1,
          );

          return Scaffold(
            appBar: buildAppBar(context, false, title: searchBar),
            bottomNavigationBar:
                (!settings.searchBarInAppBar && searchBar != null)
                ? BottomAppBar(child: searchBar)
                : null,
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
                (!settings.searchBarInAppBar && searchBar != null)
                ? BottomAppBar(child: searchBar)
                : null,
            body: Center(child: Text("Error: $err")),
          );
        },
      ),
    );
  }

  AppBar buildAppBar(BuildContext context, bool showTab, {Widget? title}) {
    final settings = ref.watch(settingsProvider);
    final locale = AppLocalizations.of(context)!;
    return AppBar(
      leading: BackButton(onPressed: () => _goBack(context)),
      title: settings.searchBarInAppBar
          ? (title ?? Text(widget.word, overflow: TextOverflow.ellipsis))
          : (widget.pagerInfo != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.word, overflow: TextOverflow.ellipsis),
                      Text(
                        "${widget.pagerInfo!.currentIndex + 1} / ${widget.pagerInfo!.totalCount}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Text(widget.word, overflow: TextOverflow.ellipsis)),
      actions: [
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
        IconButton(
          tooltip: locale.copy,
          icon: const Icon(Icons.copy),
          onPressed: () => app_utils.addToClipboard(context, widget.word),
        ),
      ],
      bottom: (showTab && settings.tabBarPosition == TabBarPosition.top)
          ? buildTabBar(context)
          : null,
    );
  }

  PreferredSizeWidget buildTabBar(BuildContext context) {
    final dictManager = ref.watch(dictManagerProvider);
    final settings = ref.watch(settingsProvider);
    final validDictIdsAsync = ref.watch(validDictIdsProvider(widget.word));

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
    final children = <Widget>[
      if (settings.aiExplainWord)
        KeepAliveWidget(
          key: const ValueKey("ai_tab"),
          child: AIExplainView(word: widget.word),
        ),
      for (final id in validDictIds)
        KeepAliveWidget(key: ValueKey("dict_$id"), child: _buildWebView(id)),
    ];
    return TabBarView(
      physics: widget.pagerInfo != null
          ? const NeverScrollableScrollPhysics()
          : null,
      children: children,
    );
  }

  Widget _buildWebView(int id) {
    return buildWebView(widget.word, id, false);
  }
}

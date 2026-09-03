import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/floating_window.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/ai_widgets.dart";
import "package:ciyue/ui/core/word_display/buttons.dart";
import "package:ciyue/ui/core/word_display/expansion_display.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
import "package:ciyue/utils.dart" as app_utils;
import "package:ciyue/viewModels/ai_explanation.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart" as legacy_provider;

class WordDisplay extends ConsumerStatefulWidget {
  final String word;

  const WordDisplay({super.key, required this.word});

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
                body: settings.aiExplainWord
                    ? AIExplainView(word: widget.word)
                    : _buildWebView(validDictIds[0]),
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
                      body: Column(
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
                          if (!settings.searchBarInAppBar && searchBar != null)
                            searchBar,
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
    return AppBar(
      leading: BackButton(onPressed: () => _goBack(context)),
      title: settings.searchBarInAppBar
          ? (title ?? Text(widget.word, overflow: TextOverflow.ellipsis))
          : Text(widget.word, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: AppLocalizations.of(context)!.copy,
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
    return TabBarView(children: children);
  }

  Widget _buildWebView(int id) {
    return buildWebView(widget.word, id, false);
  }
}

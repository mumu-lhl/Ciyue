import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/ai_widgets.dart";
import "package:ciyue/ui/core/word_display/buttons.dart";
import "package:ciyue/ui/core/word_display/expansion_display.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
import "package:ciyue/viewModels/ai_explanation.dart";
import "package:flutter/material.dart";
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
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final validDictIdsAsync = ref.watch(validDictIdsProvider(widget.word));

    return validDictIdsAsync.when(
      data: (validDictIds) {
        if (validDictIds.isEmpty && !settings.aiExplainWord) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)!.notFound,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          );
        }

        final dictsLength = settings.aiExplainWord
            ? validDictIds.length + 1
            : validDictIds.length;
        final showTab = dictsLength > 1;

        if (!showTab) {
          final searchBar = buildTitle(widget.word, settings);
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
                  final searchBar = buildTitle(widget.word, settings);

                  return Scaffold(
                    appBar: buildAppBar(context, showTab, title: searchBar),
                    floatingActionButton: ListenableBuilder(
                      listenable: tabController,
                      builder: (context, child) {
                        final isAIExplainTabSelected =
                            settings.aiExplainWord && tabController.index == 0;
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
                        if (settings.tabBarPosition == TabBarPosition.bottom &&
                            showTab)
                          buildTabBar(context),
                        if (!settings.searchBarInAppBar && searchBar != null)
                          searchBar
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
        final settings = ref.watch(settingsProvider);
        final searchBar = buildTitle(widget.word, settings);
        final firstLoadedDictId = dictManager.dictIds.firstWhere(
          (id) => dictManager.dicts[id]?.isLoading == false,
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
      error: (err, stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text("Error: $err")),
      ),
    );
  }

  AppBar buildAppBar(BuildContext context, bool showTab, {Widget? title}) {
    final settings = ref.watch(settingsProvider);
    return AppBar(
      leading: BackButton(
        onPressed: () => context.go("/"),
      ),
      title: settings.searchBarInAppBar ? title : null,
      bottom: (showTab && settings.tabBarPosition == TabBarPosition.top)
          ? buildTabBar(context)
          : null,
    );
  }

  PreferredSizeWidget buildTabBar(BuildContext context) {
    final dictManager = ref.watch(dictManagerProvider);
    final settings = ref.watch(settingsProvider);
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: FutureBuilder(
        future: Future.wait([
          for (final id in dictManager.dictIds)
            dictManager.dicts[id]!.wordExist(widget.word),
        ]),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                if (settings.aiExplainWord) Tab(text: "AI"),
                for (int i = 0; i < snapshot.data!.length; i++)
                  if (snapshot.data![i])
                    Tab(text: dictManager.dicts[dictManager.dictIds[i]]!.title),
              ],
            );
          } else {
            return const SizedBox.shrink();
          }
        },
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
          child: AIExplainView(
            word: widget.word,
            key: ValueKey(
              legacy_provider.Provider.of<AIExplanationModel>(context,
                      listen: false)
                  .refreshKey,
            ),
          ),
        ),
      for (final id in validDictIds)
        KeepAliveWidget(
          key: ValueKey("dict_$id"),
          child: _buildWebView(id),
        ),
    ];
    return TabBarView(children: children);
  }

  Widget _buildWebView(int id) {
    return buildWebView(widget.word, id, false);
  }
}

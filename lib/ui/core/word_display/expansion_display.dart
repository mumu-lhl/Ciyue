import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/floating_window.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/ai_widgets.dart";
import "package:ciyue/ui/core/word_display/audio_waveform.dart";
import "package:ciyue/ui/core/word_display/buttons.dart";
import "package:ciyue/ui/core/word_display/pager_context.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
import "package:ciyue/ui/pages/main/home/app_bar.dart" show GroupSelectorButton;
import "package:ciyue/utils.dart" as app_utils;
import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

class ExpansionWordDisplay extends ConsumerStatefulWidget {
  final String word;
  final List<int> validDictIds;
  final SearchController? searchController;
  final WordPagerInfo? pagerInfo;
  final bool showBackButton;
  final Widget? bottomNavigationBar;

  const ExpansionWordDisplay({
    super.key,
    required this.word,
    required this.validDictIds,
    this.searchController,
    this.pagerInfo,
    this.showBackButton = true,
    this.bottomNavigationBar,
  });

  @override
  ConsumerState<ExpansionWordDisplay> createState() =>
      _ExpansionWordDisplayState();
}

class _ExpansionWordDisplayState extends ConsumerState<ExpansionWordDisplay> {
  late List<Object> _panelIds;
  late List<bool> _isExpanded;
  late final SearchController _searchController;
  late final bool _ownsController;

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
    if (_ownsController) {
      _searchController.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ownsController = widget.searchController == null;
    _searchController = widget.searchController ?? SearchController();
    _panelIds = _getPanelIds(settings.aiExplainWord, widget.validDictIds);
    _isExpanded = List<bool>.filled(_panelIds.length, true);
  }

  List<Object> _getPanelIds(bool includeAI, List<int> validDictIds) => [
    if (includeAI) "ai",
    ...validDictIds.map((id) => "dict:$id"),
  ];

  void _syncPanelState(bool includeAI, List<int> validDictIds) {
    final nextPanelIds = _getPanelIds(includeAI, validDictIds);
    if (listEquals(_panelIds, nextPanelIds)) return;

    final expandedById = <Object, bool>{};
    for (var index = 0; index < _panelIds.length; index++) {
      expandedById[_panelIds[index]] = _isExpanded[index];
    }

    _panelIds = nextPanelIds;
    _isExpanded = [
      for (final panelId in nextPanelIds) expandedById[panelId] ?? true,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final dictManager = ref.watch(dictManagerProvider);
    // A group switch reloads the dictionaries; rebuild the entry views so a
    // reused platform WebView cannot come back blank.
    final groupId = dictManager.groupId;
    _syncPanelState(settings.aiExplainWord, widget.validDictIds);

    final panels = <ExpansionPanel>[];
    int panelIndex = 0;

    if (settings.aiExplainWord) {
      panels.add(
        ExpansionPanel(
          headerBuilder: (context, isExpanded) {
            return const ListTile(title: Text("AI"));
          },
          body: AIExplainView(word: widget.word),
          isExpanded: _isExpanded[panelIndex],
          canTapOnHeader: true,
        ),
      );
      panelIndex++;
    }

    for (final dictId in widget.validDictIds) {
      final expanded = _isExpanded[panelIndex];
      panels.add(
        ExpansionPanel(
          headerBuilder: (context, isExpanded) {
            return ListTile(title: Text(dictManager.dicts[dictId]!.title));
          },
          // Lazy-load the WebView only when expanded; collapsed panels
          // keep a placeholder instead of instantiating N WebViews upfront.
          body: expanded
              ? KeyedSubtree(
                  key: ValueKey("dict_${dictId}_$groupId"),
                  child: buildWebView(widget.word, dictId, true),
                )
              : const SizedBox.shrink(),
          isExpanded: expanded,
          canTapOnHeader: true,
        ),
      );
      panelIndex++;
    }

    final isAIExplainTabSelected =
        settings.aiExplainWord && _isExpanded.isNotEmpty && _isExpanded[0];

    final searchBar = _buildSearchBar(settings);
    final isDesktopScreen = app_utils.isLargeScreen(context);

    final locale = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: widget.showBackButton
            ? BackButton(onPressed: () => _goBack(context))
            : null,
        automaticallyImplyLeading: widget.showBackButton,
        title: settings.searchBarInAppBar
            ? (searchBar ?? Text(widget.word, overflow: TextOverflow.ellipsis))
            : (widget.pagerInfo != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.word, overflow: TextOverflow.ellipsis),
                        Text(
                          "${widget.pagerInfo!.currentIndex + 1} / ${widget.pagerInfo!.totalCount}",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    )
                  : Text(widget.word, overflow: TextOverflow.ellipsis)),
        actions: [
          if (settings.showSidebarIcon)
            GroupSelectorButton(compact: !isDesktopScreen),
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
            WordPronounceIconButton(word: widget.word),
            WordStarIconButton(word: widget.word),
            if (isAIExplainTabSelected) ...[
              RefreshAIExplainIconButton(word: widget.word),
              EditAIExplainIconButton(word: widget.word),
            ],
          ],
          IconButton(
            tooltip: locale.copy,
            icon: const Icon(Icons.copy),
            onPressed: () => app_utils.addToClipboard(context, widget.word),
          ),
        ],
      ),
      bottomNavigationBar:
          widget.bottomNavigationBar ??
          ((!settings.searchBarInAppBar && searchBar != null)
              ? BottomAppBar(child: searchBar)
              : null),
      floatingActionButton: isDesktopScreen
          ? null
          : Button(word: widget.word, showAIButtons: isAIExplainTabSelected),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: ExpansionPanelList(
              expansionCallback: (int index, bool isExpanded) {
                setState(() {
                  _isExpanded[index] = isExpanded;
                });
              },
              children: panels,
            ),
          ),
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
}

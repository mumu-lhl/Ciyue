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
import "package:ciyue/utils.dart" as app_utils;
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

class ExpansionWordDisplay extends ConsumerStatefulWidget {
  final String word;
  final List<int> validDictIds;
  final SearchController? searchController;
  final WordPagerInfo? pagerInfo;

  const ExpansionWordDisplay({
    super.key,
    required this.word,
    required this.validDictIds,
    this.searchController,
    this.pagerInfo,
  });

  @override
  ConsumerState<ExpansionWordDisplay> createState() =>
      _ExpansionWordDisplayState();
}

class _ExpansionWordDisplayState extends ConsumerState<ExpansionWordDisplay> {
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
    // We can't use ref here easily for initialization if it depends on ref.watch,
    // but since settings is a singleton for now, it's okay.
    // Long term we should probably pass settings in or use ref in build.
    final length = settings.aiExplainWord
        ? widget.validDictIds.length + 1
        : widget.validDictIds.length;
    _isExpanded = List<bool>.generate(length, (_) => true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final dictManager = ref.watch(dictManagerProvider);

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
      panels.add(
        ExpansionPanel(
          headerBuilder: (context, isExpanded) {
            return ListTile(title: Text(dictManager.dicts[dictId]!.title));
          },
          body: buildWebView(widget.word, dictId, true),
          isExpanded: _isExpanded[panelIndex],
          canTapOnHeader: true,
        ),
      );
      panelIndex++;
    }

    final isAIExplainTabSelected =
        settings.aiExplainWord && _isExpanded.isNotEmpty && _isExpanded[0];

    final searchBar = _buildSearchBar(settings);

    final locale = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _goBack(context)),
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
      ),
      bottomNavigationBar: (!settings.searchBarInAppBar && searchBar != null)
          ? BottomAppBar(child: searchBar)
          : null,
      floatingActionButton: Button(
        word: widget.word,
        showAIButtons: isAIExplainTabSelected,
      ),
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

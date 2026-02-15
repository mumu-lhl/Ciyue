import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/word_display/ai_widgets.dart";
import "package:ciyue/ui/core/word_display/buttons.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
import "package:ciyue/viewModels/ai_explanation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

class ExpansionWordDisplay extends ConsumerStatefulWidget {
  final String word;
  final List<int> validDictIds;

  const ExpansionWordDisplay({
    super.key,
    required this.word,
    required this.validDictIds,
  });

  @override
  ConsumerState<ExpansionWordDisplay> createState() =>
      _ExpansionWordDisplayState();
}

class _ExpansionWordDisplayState extends ConsumerState<ExpansionWordDisplay> {
  late List<bool> _isExpanded;

  @override
  void initState() {
    super.initState();
    // We can't use ref here easily for initialization if it depends on ref.watch,
    // but since settings is a singleton for now, it's okay.
    // Long term we should probably pass settings in or use ref in build.
    final length = settings.aiExplainWord
        ? widget.validDictIds.length + 1
        : widget.validDictIds.length;
    _isExpanded = List<bool>.generate(
      length,
      (_) => true,
    );
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
          body: AIExplainView(
            word: widget.word,
            key: ValueKey(context
                .select<AIExplanationModel, int>((model) => model.refreshKey)),
          ),
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

    final searchBar = buildTitle(widget.word, settings);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go("/"),
        ),
        title: settings.searchBarInAppBar ? searchBar : null,
      ),
      bottomNavigationBar: (!settings.searchBarInAppBar && searchBar != null)
          ? BottomAppBar(child: searchBar)
          : null,
      floatingActionButton: Button(
        word: widget.word,
        showAIButtons: isAIExplainTabSelected,
      ),
      body: SingleChildScrollView(
        child: ExpansionPanelList(
          expansionCallback: (int index, bool isExpanded) {
            setState(() {
              _isExpanded[index] = isExpanded;
            });
          },
          children: panels,
        ),
      ),
    );
  }
}

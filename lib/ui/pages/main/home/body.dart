import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/buttons.dart";
import "package:ciyue/ui/core/word_display/word_display.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

import "actions.dart";
import "history.dart";
import "search.dart";

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    context.select<HomeModel, int>((value) => value.state);
    context.select<DictManagerModel, bool>((value) => value.isEmpty);

    if (isLargeScreen(context)) {
      return const _DesktopHomeSplitView();
    }

    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActionButtons(),
        HistoryLabel(),
        HistoryList(),
        BottomSearchBar(),
      ],
    );
  }
}

class _DesktopHomeSplitView extends StatelessWidget {
  const _DesktopHomeSplitView();

  void _selectAdjacentHistory(
    BuildContext context,
    HomeModel homeModel,
    HistoryModel historyModel,
    int delta,
  ) {
    final history = historyModel.history;
    if (history.isEmpty) return;

    final currentWord = homeModel.selectedWord ?? history.first.word;
    final currentIndex = history.indexWhere((item) => item.word == currentWord);

    int newIndex;
    if (currentIndex == -1) {
      newIndex = delta > 0 ? 0 : history.length - 1;
    } else {
      newIndex = (currentIndex + delta).clamp(0, history.length - 1);
    }

    homeModel.selectedWord = history[newIndex].word;
  }

  @override
  Widget build(BuildContext context) {
    final homeModel = context.watch<HomeModel>();
    final historyModel = context.watch<HistoryModel>();
    final selectedWord = homeModel.selectedWord;
    final activeWord =
        selectedWord ??
        (historyModel.history.isNotEmpty
            ? historyModel.history.first.word
            : null);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          homeModel.focusSearchBar();
          if (homeModel.searchController.isAttached) {
            homeModel.searchController.openView();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          if (!homeModel.searchBarFocusNode.hasFocus) {
            _selectAdjacentHistory(context, homeModel, historyModel, 1);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          if (!homeModel.searchBarFocusNode.hasFocus) {
            _selectAdjacentHistory(context, homeModel, historyModel, -1);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          if (activeWord != null && activeWord.isNotEmpty) {
            playWordPronunciation(context, activeWord);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Row(
          children: [
            SizedBox(
              width: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: HomeSearchBar(
                      onWordSelected: (word) {
                        homeModel.selectedWord = word;
                      },
                    ),
                  ),
                  const ActionButtons(),
                  const HistoryLabel(),
                  HistoryList(
                    selectedWord: selectedWord,
                    onWordSelected: (word) {
                      homeModel.selectedWord = word;
                    },
                  ),
                ],
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: selectedWord != null && selectedWord.isNotEmpty
                  ? KeyedSubtree(
                      key: ValueKey(selectedWord),
                      child: WordDisplay(
                        word: selectedWord,
                        showBackButton: false,
                      ),
                    )
                  : (historyModel.history.isNotEmpty
                        ? KeyedSubtree(
                            key: ValueKey(historyModel.history.first.word),
                            child: WordDisplay(
                              word: historyModel.history.first.word,
                              showBackButton: false,
                            ),
                          )
                        : Center(
                            child: Text(
                              AppLocalizations.of(context)!.startToSearch,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          )),
            ),
          ],
        ),
      ),
    );
  }
}

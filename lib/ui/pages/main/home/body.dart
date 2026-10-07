import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/word_display.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:material_ui/material_ui.dart";
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

  @override
  Widget build(BuildContext context) {
    final homeModel = context.watch<HomeModel>();
    final historyModel = context.watch<HistoryModel>();
    final selectedWord = homeModel.selectedWord;

    return Row(
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
                  child: WordDisplay(word: selectedWord, showBackButton: false),
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
    );
  }
}

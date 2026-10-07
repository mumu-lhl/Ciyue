import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/buttons.dart";
import "package:ciyue/ui/core/word_display/word_display.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/gestures.dart";
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

    if (homeModel.tabs.isEmpty &&
        historyModel.history.isNotEmpty &&
        selectedWord == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (homeModel.tabs.isEmpty && historyModel.history.isNotEmpty) {
          homeModel.ensureInitialWord(historyModel.history.first.word);
        }
      });
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          homeModel.focusSearchBar();
          if (homeModel.searchController.isAttached) {
            homeModel.searchController.openView();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () {
          homeModel.newTab();
        },
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
          if (homeModel.tabs.isNotEmpty && homeModel.activeTabIndex >= 0) {
            homeModel.closeTab(homeModel.activeTabIndex);
          }
        },
        const SingleActivator(LogicalKeyboardKey.tab, control: true): () {
          homeModel.nextTab();
        },
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): () {
          homeModel.previousTab();
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
                    onWordTertiarySelected: (word) {
                      homeModel.openWordInNewTab(word);
                    },
                  ),
                ],
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (homeModel.tabs.isNotEmpty) const _DesktopWordTabBar(),
                  Expanded(
                    child: selectedWord != null && selectedWord.isNotEmpty
                        ? KeyedSubtree(
                            key: ValueKey(selectedWord),
                            child: WordDisplay(
                              word: selectedWord,
                              showBackButton: false,
                            ),
                          )
                        : (historyModel.history.isNotEmpty &&
                                  homeModel.tabs.isEmpty
                              ? KeyedSubtree(
                                  key: ValueKey(
                                    historyModel.history.first.word,
                                  ),
                                  child: WordDisplay(
                                    word: historyModel.history.first.word,
                                    showBackButton: false,
                                  ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_rounded,
                                        size: 56,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        AppLocalizations.of(context)!
                                            .startToSearch,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton.tonalIcon(
                                        onPressed: () => homeModel.newTab(),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: Text(
                                          AppLocalizations.of(context)!.newTab,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopWordTabBar extends StatelessWidget {
  const _DesktopWordTabBar();

  void _showTabContextMenu(
    BuildContext context,
    TapDownDetails details,
    int index,
    HomeModel homeModel,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final position = RelativeRect.fromRect(
      details.globalPosition & const Size(40, 40),
      Offset.zero & MediaQuery.sizeOf(context),
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: "close",
          child: Row(
            children: [
              const Icon(Icons.close, size: 18),
              const SizedBox(width: 8),
              Text(l10n.closeTab),
            ],
          ),
        ),
        if (homeModel.tabs.length > 1)
          PopupMenuItem(
            value: "closeOthers",
            child: Row(
              children: [
                const Icon(Icons.clear_all, size: 18),
                const SizedBox(width: 8),
                Text(l10n.closeOtherTabs),
              ],
            ),
          ),
        PopupMenuItem(
          value: "closeAll",
          child: Row(
            children: [
              const Icon(Icons.cancel_outlined, size: 18),
              const SizedBox(width: 8),
              Text(l10n.closeAllTabs),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == "close") {
        homeModel.closeTab(index);
      } else if (value == "closeOthers") {
        homeModel.closeOtherTabs(index);
      } else if (value == "closeAll") {
        homeModel.closeAllTabs();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeModel = context.watch<HomeModel>();
    final tabs = homeModel.tabs;
    final activeIndex = homeModel.activeTabIndex;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              itemCount: tabs.length,
              separatorBuilder: (context, index) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final word = tabs[index];
                final isActive = index == activeIndex;
                final displayText = word.isEmpty ? l10n.newTab : word;

                TapDownDetails? tapDownDetails;

                return Listener(
                  onPointerDown: (event) {
                    if (event.buttons == kTertiaryButton) {
                      homeModel.closeTab(index);
                    }
                  },
                  child: GestureDetector(
                    onTapDown: (details) => tapDownDetails = details,
                    onSecondaryTap: () {
                      if (tapDownDetails != null) {
                        _showTabContextMenu(
                          context,
                          tapDownDetails!,
                          index,
                          homeModel,
                        );
                      }
                    },
                    child: Tooltip(
                      message: displayText,
                      waitDuration: const Duration(milliseconds: 500),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => homeModel.switchToTab(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          constraints: const BoxConstraints(
                            minWidth: 70,
                            maxWidth: 180,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? theme.colorScheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? theme.colorScheme.outlineVariant
                                  : Colors.transparent,
                              width: 1,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.shadow
                                          .withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  displayText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isActive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkResponse(
                                radius: 10,
                                onTap: () => homeModel.closeTab(index),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: isActive
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: "${l10n.newTab} (Ctrl+T)",
            splashRadius: 16,
            onPressed: () => homeModel.newTab(),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

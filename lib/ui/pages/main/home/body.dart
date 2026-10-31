import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/word_display.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/home.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/gestures.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "actions.dart";
import "history.dart";
import "search.dart";
import "shortcuts.dart";

/// Keeps the desktop WordDisplay state alive as the selected word changes.
class DesktopWordDisplayPane extends StatelessWidget {
  final String word;

  const DesktopWordDisplayPane({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    return WordDisplay(word: word, showBackButton: false);
  }
}

class HomeBody extends ConsumerWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeModelProvider.select((value) => value.state));
    ref.watch(dictManagerModelProvider.select((value) => value.isEmpty));

    final content = isLargeScreen(context)
        ? const _DesktopHomeSplitView()
        : const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActionButtons(),
              HistoryLabel(),
              HistoryList(),
              BottomSearchBar(),
            ],
          );

    return SearchEscapeCloser(child: content);
  }
}

class _DesktopHomeSplitView extends ConsumerWidget {
  const _DesktopHomeSplitView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Subscribe narrowly: rebuilding the whole split view (and the WordDisplay
    // inside it) on every history write or tab mutation is expensive.
    // Imperative calls below use ref.read so they don't subscribe.
    final homeModel = ref.read(homeModelProvider);
    // The split view's own search box is the page's default; the entry pane
    // keeps its showBackButton false so it does not override this.
    pageSearchFocusNode = homeModel.searchBarFocusNode;
    final selectedWord = ref.watch(
      homeModelProvider.select((model) => model.selectedWord),
    );
    final tabsEmpty = ref.watch(
      homeModelProvider.select((model) => model.tabs.isEmpty),
    );
    final historyEmpty = ref.watch(
      historyModelProvider.select((model) => model.history.isEmpty),
    );
    final firstHistoryWord = ref.watch(
      historyModelProvider.select(
        (model) => model.history.isEmpty ? null : model.history.first.word,
      ),
    );

    if (tabsEmpty && !historyEmpty && selectedWord == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final liveHomeModel = ref.read(homeModelProvider);
        final liveHistoryModel = ref.read(historyModelProvider);
        if (liveHomeModel.tabs.isEmpty && liveHistoryModel.history.isNotEmpty) {
          liveHomeModel.ensureInitialWord(liveHistoryModel.history.first.word);
        }
      });
    }

    return CallbackShortcuts(
      bindings: homeShortcutBindings(ref, context),
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
                  if (!tabsEmpty) const _DesktopWordTabBar(),
                  Expanded(
                    child: selectedWord != null && selectedWord.isNotEmpty
                        ? DesktopWordDisplayPane(word: selectedWord)
                        : (!historyEmpty && tabsEmpty
                              ? DesktopWordDisplayPane(word: firstHistoryWord!)
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

class _DesktopWordTabBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // HomeModel.tabs allocates a new list on every access, so selecting the
    // list itself would rebuild on every notification. Select a joined string
    // instead: it only changes when a tab's word actually changes.
    final tabWords = ref.watch(
      homeModelProvider.select((model) => model.tabs.join("\u0000")),
    );
    final List<String> tabs = tabWords.isEmpty
        ? const []
        : tabWords.split("\u0000");
    final activeIndex = ref.watch(
      homeModelProvider.select((model) => model.activeTabIndex),
    );
    final homeModel = ref.read(homeModelProvider);
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
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              itemCount: tabs.length,
              onReorderItem: (oldIndex, newIndex) {
                homeModel.reorderTabs(oldIndex, newIndex);
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  color: Colors.transparent,
                  shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final word = tabs[index];
                final isActive = index == activeIndex;
                final displayText = word.isEmpty ? l10n.newTab : word;

                TapDownDetails? tapDownDetails;

                return Padding(
                  key: ValueKey(word.isEmpty ? "__ciyue_empty_tab__" : word),
                  padding: const EdgeInsets.only(right: 4),
                  child: ReorderableDragStartListener(
                    index: index,
                    child: Listener(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
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
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: isActive
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isActive
                                                ? theme.colorScheme.primary
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
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

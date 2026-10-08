import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:ciyue/ui/core/word_display/word_display.dart";
import "package:ciyue/viewModels/home.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

/// A Chrome-style mobile browser container for word lookup on small screens.
/// Supports a bottom navigation bar with back/forward history, new tab, and tab switcher.
class MobileWordBrowser extends ConsumerStatefulWidget {
  final String initialWord;
  final int? initialDictId;

  const MobileWordBrowser({
    super.key,
    required this.initialWord,
    this.initialDictId,
  });

  @override
  ConsumerState<MobileWordBrowser> createState() => _MobileWordBrowserState();
}

class _MobileWordBrowserState extends ConsumerState<MobileWordBrowser> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final homeModel = ref.read(homeModelProvider);
      if (homeModel.tabs.isEmpty) {
        homeModel.ensureInitialWord(
          widget.initialWord,
          dictId: widget.initialDictId,
        );
      } else if (homeModel.selectedWord != widget.initialWord &&
          widget.initialWord.isNotEmpty) {
        final existingIndex = homeModel.tabs.indexOf(widget.initialWord);
        if (existingIndex != -1) {
          homeModel.switchToTab(existingIndex);
        } else {
          homeModel.openWordInNewTab(
            widget.initialWord,
            dictId: widget.initialDictId,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeModel = ref.watch(homeModelProvider);
    final activeWord = homeModel.selectedWord ?? widget.initialWord;
    final activeDictId = homeModel.activeDictId ?? widget.initialDictId;

    final canPopBack =
        !homeModel.isTabOverviewOpen &&
        !homeModel.canGoBack &&
        activeWord.isNotEmpty;

    return PopScope(
      canPop: canPopBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (homeModel.isTabOverviewOpen) {
          homeModel.setTabOverviewOpen(false);
        } else if (activeWord.isEmpty) {
          homeModel.closeTab(homeModel.activeTabIndex);
          if (homeModel.tabs.isEmpty && context.canPop()) {
            context.pop();
          }
        } else if (homeModel.canGoBack) {
          homeModel.goBack();
        }
      },
      child: homeModel.isTabOverviewOpen
          ? MobileTabOverview(homeModel: homeModel)
          : (activeWord.isEmpty
                ? MobileNewTabPage(homeModel: homeModel)
                : WordDisplay(
                    key: ValueKey(
                      "tab_${homeModel.activeTab?.id ?? activeWord}",
                    ),
                    word: activeWord,
                    initialDictId: activeDictId,
                    showBackButton: true,
                    bottomNavigationBar: MobileWordBottomBar(
                      homeModel: homeModel,
                    ),
                  )),
    );
  }
}

/// Dedicated New Tab page displayed when a newly created tab has no word yet.
class MobileNewTabPage extends ConsumerWidget {
  final HomeModel homeModel;

  const MobileNewTabPage({super.key, required this.homeModel});

  void _selectWord(WidgetRef ref, String word) {
    final normalized = word.trim();
    if (normalized.isEmpty) return;
    homeModel.selectedWord = normalized;
    ref.read(openRecordsRepositoryProvider).add(normalized);
    ref.read(historyModelProvider).addHistory(normalized);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final history = ref.watch(historyModelProvider).history;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            homeModel.closeTab(homeModel.activeTabIndex);
            if (homeModel.tabs.isEmpty && context.canPop()) {
              context.pop();
            }
          },
        ),
        title: Text(locale.newTab),
      ),
      bottomNavigationBar: MobileWordBottomBar(homeModel: homeModel),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WordSearchBarWithSuggestions(
                word: "",
                controller: homeModel.searchController,
                focusNode: homeModel.searchBarFocusNode,
                autoFocus: true,
                isHome: true,
                onWordSelected: (word) => _selectWord(ref, word),
              ),
              if (history.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      locale.history,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      tooltip: locale.clearHistory,
                      icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                      onPressed: () async {
                        final confirm =
                            await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(locale.clearHistory),
                                content: Text(locale.clearHistoryConfirm),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: Text(locale.cancel),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: Text(locale.confirm),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                        if (confirm) {
                          ref.read(historyModelProvider).clearHistory();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in history.take(12))
                      InputChip(
                        label: Text(item.word),
                        avatar: const Icon(Icons.history_rounded, size: 16),
                        onPressed: () => _selectWord(ref, item.word),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        deleteButtonTooltipMessage: locale.delete,
                        onDeleted: () {
                          ref.read(historyModelProvider).deleteHistory(item.id);
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chrome-style bottom bar on mobile screen.
class MobileWordBottomBar extends ConsumerWidget {
  final HomeModel homeModel;

  const MobileWordBottomBar({super.key, required this.homeModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: locale.back,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: homeModel.canGoBack
                    ? () => homeModel.goBack()
                    : null,
              ),
              IconButton(
                tooltip: locale.forward,
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: homeModel.canGoForward
                    ? () => homeModel.goForward()
                    : null,
              ),
              IconButton(
                tooltip: locale.newTab,
                icon: const Icon(Icons.add_rounded),
                onPressed: () => homeModel.newTab(),
              ),
              Tooltip(
                message: locale.tabs,
                child: InkWell(
                  onTap: () => homeModel.toggleTabOverview(),
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colorScheme.onSurfaceVariant,
                        width: 1.8,
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      "${homeModel.tabs.length}",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: locale.more,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  switch (value) {
                    case "close_tab":
                      homeModel.closeTab(homeModel.activeTabIndex);
                      if (homeModel.tabs.isEmpty && context.canPop()) {
                        context.pop();
                      }
                      break;
                    case "close_other_tabs":
                      homeModel.closeOtherTabs(homeModel.activeTabIndex);
                      break;
                    case "close_all_tabs":
                      homeModel.closeAllTabs();
                      if (context.canPop()) {
                        context.pop();
                      }
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: "close_tab",
                    child: Row(
                      children: [
                        const Icon(Icons.close_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(locale.closeTab),
                      ],
                    ),
                  ),
                  if (homeModel.tabs.length > 1)
                    PopupMenuItem(
                      value: "close_other_tabs",
                      child: Row(
                        children: [
                          const Icon(Icons.tab_unselected_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(locale.closeOtherTabs),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: "close_all_tabs",
                    child: Row(
                      children: [
                        const Icon(Icons.clear_all_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(locale.closeAllTabs),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chrome-style tab overview / switcher page.
class MobileTabOverview extends ConsumerWidget {
  final HomeModel homeModel;

  const MobileTabOverview({super.key, required this.homeModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tabs = homeModel.wordTabs;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => homeModel.setTabOverviewOpen(false),
        ),
        title: Text("${locale.tabs} (${tabs.length})"),
        actions: [
          IconButton(
            tooltip: locale.newTab,
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              homeModel.newTab();
              homeModel.setTabOverviewOpen(false);
            },
          ),
          if (tabs.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == "close_all") {
                  homeModel.closeAllTabs();
                  if (context.canPop()) {
                    context.pop();
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: "close_all",
                  child: Row(
                    children: [
                      const Icon(Icons.clear_all_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(locale.closeAllTabs),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: tabs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tab_rounded,
                    size: 64,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    locale.noOpenTabs,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      homeModel.newTab();
                      homeModel.setTabOverviewOpen(false);
                    },
                    icon: const Icon(Icons.add),
                    label: Text(locale.newTab),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isActive = index == homeModel.activeTabIndex;

                return Dismissible(
                  key: ValueKey(tab.id),
                  onDismissed: (_) {
                    homeModel.closeTab(index);
                    if (homeModel.tabs.isEmpty && context.canPop()) {
                      context.pop();
                    }
                  },
                  child: Card(
                    elevation: isActive ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isActive
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    color: isActive
                        ? colorScheme.primaryContainer.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerLow,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => homeModel.switchToTab(index),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tab.currentWord.isEmpty
                                        ? locale.newTab
                                        : tab.currentWord,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isActive
                                          ? colorScheme.primary
                                          : colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    homeModel.closeTab(index);
                                    if (homeModel.tabs.isEmpty &&
                                        context.canPop()) {
                                      context.pop();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      tab.currentWord.isEmpty
                                          ? Icons.search_rounded
                                          : Icons.menu_book_rounded,
                                      size: 32,
                                      color: isActive
                                          ? colorScheme.primary
                                          : colorScheme.outline,
                                    ),
                                    if (tab.history.length > 1) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        "${tab.history.length} ${locale.history}",
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

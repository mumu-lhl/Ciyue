import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "more_button.dart";
import "search.dart";

class HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(historyModelProvider);

    if (model.isSelecting) {
      return AppBar(
        title: Text(
          AppLocalizations.of(context)!.nSelected(model.selectedIds.length),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            model.clearSelection();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: () => model.selectAll(),
          ),
          IconButton(
            icon: const Icon(Icons.book_outlined),
            onPressed: () async {
              await model.addSelectedToWordbook(
                ref.read(wordbookModelProvider),
              );
              ref.read(wordbookModelProvider).updateWordList();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => model.deleteSelected(),
          ),
        ],
      );
    } else {
      final isDesktop = MediaQuery.sizeOf(context).width >= 600.0;
      final searchBar = (settings.searchBarInAppBar && !isDesktop)
          ? const HomeSearchBar()
          : null;

      return AppBar(
        title: searchBar,
        automaticallyImplyLeading: settings.showSidebarIcon && !isDesktop,
        actions: [
          const GroupSelectorButton(),
          if (settings.showMoreOptionsButton) const MoreButton(),
        ],
      );
    }
  }
}

class GroupSelectorButton extends ConsumerWidget {
  const GroupSelectorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dictManagerModel = ref.watch(dictManagerModelProvider);
    final groupId = dictManagerModel.groupId;
    final isSwitchingGroup = dictManagerModel.isSwitchingGroup;

    final currentGroup = dictManager.groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => dictManager.groups.first,
    );
    final groupName = currentGroup.name == "Default"
        ? AppLocalizations.of(context)!.default_
        : currentGroup.name;

    return PopupMenuButton<int>(
      tooltip: AppLocalizations.of(context)!.dictionaryGroups,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.collections_bookmark_outlined, size: 20),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              groupName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
      enabled: !isSwitchingGroup,
      onSelected: (int selectedGroupId) async {
        if (selectedGroupId != groupId) {
          await ref
              .read(dictManagerModelProvider)
              .setCurrentGroup(selectedGroupId);
        }
      },
      itemBuilder: (context) => [
        for (final group in dictManager.groups)
          PopupMenuItem<int>(
            value: group.id,
            child: Row(
              children: [
                Icon(
                  group.id == groupId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: group.id == groupId
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.name == "Default"
                        ? AppLocalizations.of(context)!.default_
                        : group.name,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

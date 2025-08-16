import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "more_button.dart";
import "search.dart";

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({
    super.key,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final model = context.watch<HistoryModel>();

    if (model.isSelecting) {
      return AppBar(
        title: Text(
            AppLocalizations.of(context)!.nSelected(model.selectedIds.length)),
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
              await model.addSelectedToWordbook();
              if (context.mounted) {
                context.read<WordbookModel>().updateWordList();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => model.deleteSelected(),
          ),
        ],
      );
    } else {
      final searchBar =
          settings.searchBarInAppBar ? const HomeSearchBar() : null;

      return AppBar(
        title: searchBar,
        automaticallyImplyLeading: settings.showSidebarIcon,
        actions: [
          if (settings.showMoreOptionsButton) const MoreButton(),
        ],
      );
    }
  }
}

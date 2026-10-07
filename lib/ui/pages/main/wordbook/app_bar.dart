import "package:ciyue/core/providers.dart";
import "package:ciyue/utils.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "dialogs.dart";

class WordbookAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const WordbookAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(wordbookModelProvider);

    return AppBar(
      actions: [
        if (model.isMultiSelectMode)
          _MultiSelectActions()
        else
          _NormalActions(),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _NormalActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(wordbookModelProvider);
    final isDesktop = isLargeScreen(context);

    return Row(
      children: [
        if (isDesktop) ...[
          IconButton(
            tooltip: "Search",
            icon: const Icon(Icons.search),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const SearchWordDialog(),
              );
            },
          ),
          if (model.selectedDate != null)
            IconButton(
              tooltip: "Clear date",
              icon: const Icon(Icons.clear),
              onPressed: () {
                model.selectedDate = null;
                model.updateWordList();
              },
            ),
          IconButton(
            tooltip: "Calendar",
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final DateTime? picked = await showDialog(
                context: context,
                builder: (BuildContext context) => const MonthPickerDialog(),
              );
              if (picked != null && context.mounted) {
                model.selectedDate = picked;
                model.updateWordList();
              }
            },
          ),
        ],
        IconButton(
          icon: const Icon(Icons.label_outline),
          onPressed: () async {
            final tags = await model.tags;
            if (!context.mounted) return;
            if (tags.isEmpty) {
              await model.showAddTagDialog(context);
            } else {
              await model.showTagsListDialog(context);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () async {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return const MoreOptionsDialog();
              },
            );
          },
        ),
      ],
    );
  }
}

class _MultiSelectActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(wordbookModelProvider);
    final isSelectedWordsEmpty = model.selectedWords.isEmpty;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            model.toggleMultiSelectMode();
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: isSelectedWordsEmpty
              ? null
              : () {
                  model.showDeleteConfirmationDialog(context);
                },
        ),
      ],
    );
  }
}

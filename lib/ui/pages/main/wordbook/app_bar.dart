import "package:ciyue/viewModels/wordbook.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "dialogs.dart";

class WordbookAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WordbookAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<WordbookModel>();

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

class _NormalActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.read<WordbookModel>();
    return Row(
      children: [
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

class _MultiSelectActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<WordbookModel>();
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

import "package:ciyue/database/app/app.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/history_page.dart";
import "package:ciyue/viewModels/writing_check_history.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class WritingCheckHistoryPage extends StatelessWidget {
  const WritingCheckHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider(
      create: (context) => WritingCheckHistoryViewModel(),
      child: HistoryPage<WritingCheckHistoryData, WritingCheckHistoryViewModel>(
        title: l10n.writingCheckHistory,
        itemBuilder: (context, item) {
          return _HistoryListItem(key: ValueKey(item.id), item: item);
        },
      ),
    );
  }
}

class _HistoryListItem extends StatelessWidget {
  const _HistoryListItem({super.key, required this.item});

  final WritingCheckHistoryData item;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<WritingCheckHistoryViewModel>();
    final isSelected = context.select(
        (WritingCheckHistoryViewModel vm) => vm.selectedIds.contains(item.id));
    final isSelecting =
        context.select((WritingCheckHistoryViewModel vm) => vm.isSelecting);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        title: Text(
          item.inputText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.outputText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        onTap: () {
          if (isSelecting) {
            viewModel.toggleSelection(item.id);
          } else {
            Navigator.of(context).pop(item);
          }
        },
        onLongPress: () {
          viewModel.toggleSelection(item.id);
        },
        trailing: isSelecting
            ? Checkbox(
                value: isSelected,
                onChanged: (value) {
                  viewModel.toggleSelection(item.id);
                },
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  viewModel.deleteHistory(item.id);
                },
              ),
      ),
    );
  }
}

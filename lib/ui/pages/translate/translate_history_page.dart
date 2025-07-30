import "package:ciyue/database/app/app.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/history_page.dart";
import "package:ciyue/viewModels/translate_history_view_model.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";

class TranslateHistoryPage extends StatelessWidget {
  const TranslateHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider(
      create: (context) => TranslateHistoryViewModel(),
      child: HistoryPage<TranslateHistoryData, TranslateHistoryViewModel>(
        title: l10n.translationHistory,
        itemBuilder: (context, item) {
          return _HistoryListItem(key: ValueKey(item.id), item: item);
        },
      ),
    );
  }
}

class _HistoryListItem extends StatelessWidget {
  const _HistoryListItem({super.key, required this.item});

  final TranslateHistoryData item;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<TranslateHistoryViewModel>();
    final isSelecting =
        context.select((TranslateHistoryViewModel vm) => vm.isSelecting);
    final isSelected = context.select(
        (TranslateHistoryViewModel vm) => vm.selectedIds.contains(item.id));

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
          DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
              .add_jm()
              .format(item.createdAt),
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

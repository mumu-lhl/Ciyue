import "package:ciyue/database/app/app.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/translate_history_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class TranslateHistoryPage extends StatelessWidget {
  const TranslateHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TranslateHistoryViewModel(),
      child: const _TranslateHistoryPage(),
    );
  }
}

class _TranslateHistoryPage extends StatelessWidget {
  const _TranslateHistoryPage();

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context.select((TranslateHistoryViewModel vm) => vm.isLoading);
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final historyIsEmpty =
        context.select((TranslateHistoryViewModel vm) => vm.history.isEmpty);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: const _AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: historyIsEmpty
                ? Center(
                    child: Text(
                      l10n.empty,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  )
                : const _HistoryList(),
          ),
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = context.read<TranslateHistoryViewModel>();
    final isSelecting =
        context.select((TranslateHistoryViewModel vm) => vm.isSelecting);
    final selectedCount =
        context.select((TranslateHistoryViewModel vm) => vm.selectedIds.length);

    return AppBar(
      title: isSelecting
          ? Text(l10n.nSelected(selectedCount))
          : Text(l10n.translationHistory),
      leading: isSelecting
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: viewModel.clearSelection,
            )
          : null,
      actions: [
        if (isSelecting)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: viewModel.deleteSelected,
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HistoryList extends StatelessWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<TranslateHistoryViewModel>().history;
    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        return _HistoryListItem(key: ValueKey(item.id), item: item);
      },
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
    final isSelected = context
        .select((TranslateHistoryViewModel vm) => vm.selectedIds.contains(item.id));

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color:
          isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        title: Text(
          item.inputText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

import "package:ciyue/database/app/app.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/writing_check_history.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class WritingCheckHistoryPage extends StatelessWidget {
  const WritingCheckHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WritingCheckHistoryViewModel(),
      child: const _WritingCheckHistoryPage(),
    );
  }
}

class _WritingCheckHistoryPage extends StatelessWidget {
  const _WritingCheckHistoryPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: _HistoryAppBar(),
      body: _HistoryBody(),
    );
  }
}

class _HistoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HistoryAppBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = context.watch<WritingCheckHistoryViewModel>();
    final isSelecting = viewModel.isSelecting;
    final selectedCount = viewModel.selectedIds.length;

    return AppBar(
      title: isSelecting
          ? Text(l10n.nSelected(selectedCount))
          : Text(l10n.writingCheckHistory),
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

class _HistoryBody extends StatelessWidget {
  const _HistoryBody();

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context.select((WritingCheckHistoryViewModel vm) => vm.isLoading);
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final history =
        context.select((WritingCheckHistoryViewModel vm) => vm.history);
    if (history.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.empty,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return _HistoryListItem(key: ValueKey(item.id), item: item);
            },
          ),
        ),
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

import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/history_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class HistoryPage<T, VM extends HistoryViewModel<T>> extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext context, T item) itemBuilder;

  const HistoryPage({
    super.key,
    required this.title,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select((VM vm) => vm.isLoading);
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final historyIsEmpty = context.select((VM vm) => vm.history.isEmpty);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: _AppBar<T, VM>(title: title),
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
                : _HistoryList<T, VM>(itemBuilder: itemBuilder),
          ),
        ),
      ),
    );
  }
}

class _AppBar<T, VM extends HistoryViewModel<T>> extends StatelessWidget
    implements PreferredSizeWidget {
  const _AppBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = context.read<VM>();
    final isSelecting = context.select((VM vm) => vm.isSelecting);
    final selectedCount = context.select((VM vm) => vm.selectedIds.length);

    return AppBar(
      title: isSelecting ? Text(l10n.nSelected(selectedCount)) : Text(title),
      leading: isSelecting
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: viewModel.clearSelection,
            )
          : null,
      actions: [
        if (isSelecting) ...[
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: viewModel.selectAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: viewModel.deleteSelected,
          ),
        ]
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HistoryList<T, VM extends HistoryViewModel<T>> extends StatelessWidget {
  const _HistoryList({required this.itemBuilder});

  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final history = context.watch<VM>().history;
    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        return itemBuilder(context, item);
      },
    );
  }
}

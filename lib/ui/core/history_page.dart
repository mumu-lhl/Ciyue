import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/history_view_model.dart";
import "package:material_ui/material_ui.dart";

class HistoryPage<T, VM extends HistoryViewModel<T>> extends StatelessWidget {
  final String title;
  final VM viewModel;
  final Widget Function(BuildContext context, T item, VM viewModel) itemBuilder;

  const HistoryPage({
    super.key,
    required this.title,
    required this.viewModel,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final l10n = AppLocalizations.of(context)!;
        final isSelecting = viewModel.isSelecting;
        final selectedCount = viewModel.selectedIds.length;

        return Scaffold(
          appBar: AppBar(
            title: isSelecting
                ? Text(l10n.nSelected(selectedCount))
                : Text(title),
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
              ],
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: viewModel.history.isEmpty
                    ? Center(
                        child: Text(
                          l10n.empty,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      )
                    : ListView.builder(
                        itemCount: viewModel.history.length,
                        itemBuilder: (context, index) {
                          final item = viewModel.history[index];
                          return itemBuilder(context, item, viewModel);
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

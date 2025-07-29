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
    return Consumer<WritingCheckHistoryViewModel>(
      builder: (context, viewModel, child) {
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          appBar: AppBar(
            title: viewModel.isSelecting
                ? Text(l10n.nSelected(viewModel.selectedIds.length))
                : Text(l10n.writingCheckHistory),
            leading: viewModel.isSelecting
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: viewModel.clearSelection,
                  )
                : null,
            actions: [
              if (viewModel.isSelecting)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: viewModel.deleteSelected,
                ),
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
                          final isSelected =
                              viewModel.selectedIds.contains(item.id);
                          return Card(
                            key: ValueKey(item.id),
                            clipBehavior: Clip.antiAlias,
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                              onTap: () {
                                if (viewModel.isSelecting) {
                                  viewModel.toggleSelection(item.id);
                                } else {
                                  Navigator.of(context).pop(item);
                                }
                              },
                              onLongPress: () {
                                viewModel.toggleSelection(item.id);
                              },
                              trailing: viewModel.isSelecting
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

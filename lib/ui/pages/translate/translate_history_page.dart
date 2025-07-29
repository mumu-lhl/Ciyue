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
    return Consumer<TranslateHistoryViewModel>(
      builder: (context, viewModel, child) {
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.translationHistory),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: viewModel.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : viewModel.history.isEmpty
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
                              return Card(
                                key: ValueKey(item.id),
                                clipBehavior: Clip.antiAlias,
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                child: ListTile(
                                  title: Text(
                                    item.inputText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop(item);
                                  },
                                  trailing: IconButton(
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

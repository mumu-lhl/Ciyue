import "package:ciyue/repositories/writing_check_history.dart";
import "package:ciyue/viewModels/writing_check_history.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class WritingCheckHistoryPage extends StatelessWidget {
  const WritingCheckHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WritingCheckHistoryViewModel(
        WritingCheckHistoryRepository.of(context),
      ),
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
        return Scaffold(
          appBar: AppBar(
            title: const Text("Writing Check History"),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView.builder(
                  itemCount: viewModel.history.length,
                  itemBuilder: (context, index) {
                    final item = viewModel.history[index];
                    return Card(
                      key: ValueKey(item.id),
                      clipBehavior: Clip.antiAlias,
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
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

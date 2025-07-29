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
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop(item);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.inputText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.outputText,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                            ],
                          ),
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

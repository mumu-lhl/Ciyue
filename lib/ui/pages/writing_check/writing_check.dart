import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/writing_check.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:ciyue/ui/core/ai_markdown.dart";

class WritingCheckPage extends StatelessWidget {
  const WritingCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WritingCheckViewModel(),
      child: const _WritingCheckPage(),
    );
  }
}

class _WritingCheckPage extends StatelessWidget {
  const _WritingCheckPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<WritingCheckViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.writingCheck),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: viewModel.textEditingController,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!
                              .label_enter_to_check,
                          alignLabelWithHint: true,
                        ),
                        maxLines: 10,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: viewModel.check,
                        child: Text(AppLocalizations.of(context)!.check),
                      ),
                      const SizedBox(height: 16),
                      if (viewModel.prompt != null)
                        Expanded(
                          child: AIMarkdown(
                            prompt: viewModel.prompt!,
                            onResult: (outputText) {
                              viewModel.saveResult(outputText);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ));
      },
    );
  }
}

import "package:ciyue/database/app/app.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/custom_context_menu.dart";
import "package:ciyue/viewModels/selection_text_view_model.dart";
import "package:ciyue/viewModels/writing_check.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:provider/provider.dart";
import "package:ciyue/ui/core/ai_markdown.dart";

import "package:ciyue/utils.dart";
import "package:flutter/services.dart";

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
    final isDesktop = isLargeScreen(context);

    return Consumer<WritingCheckViewModel>(
      builder: (context, viewModel, child) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
              if (viewModel.textEditingController.text.isNotEmpty) {
                viewModel.check();
              }
            },
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.writingCheck),
              actions: [
                IconButton(
                  tooltip: AppLocalizations.of(context)!.history,
                  icon: const Icon(Icons.history),
                  onPressed: () async {
                    final result = await context.push("/writing_check/history");
                    if (result is WritingCheckHistoryData) {
                      viewModel.loadFromHistory(result);
                    }
                  },
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.settings,
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    context.push("/writing_check/settings");
                  },
                ),
              ],
            ),
            body: isDesktop
                ? _DesktopWritingCheckView(viewModel: viewModel)
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: SingleChildScrollView(
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
                                contextMenuBuilder:
                                    buildEditableTextCustomContextMenu(
                                      fallbackText:
                                          viewModel.textEditingController.text,
                                    ),
                                maxLines: 5,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: viewModel.check,
                                child: Text(
                                  AppLocalizations.of(context)!.check,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (viewModel.prompt != null)
                                AIMarkdown(
                                  prompt: viewModel.prompt!,
                                  onResult: (outputText) {
                                    viewModel.saveResult(outputText);
                                  },
                                ),
                              if (viewModel.outputText != null)
                                SelectionArea(
                                  onSelectionChanged: context
                                      .read<SelectionTextViewModel>()
                                      .setSelectedText,
                                  contextMenuBuilder: buildCustomContextMenu(
                                    fallbackText: viewModel.outputText!,
                                  ),
                                  child: GptMarkdown(viewModel.outputText!),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _DesktopWritingCheckView extends StatelessWidget {
  final WritingCheckViewModel viewModel;

  const _DesktopWritingCheckView({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Input Card
          Expanded(
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: viewModel.textEditingController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: locale.label_enter_to_check,
                          border: InputBorder.none,
                        ),
                        contextMenuBuilder: buildEditableTextCustomContextMenu(
                          fallbackText: viewModel.textEditingController.text,
                        ),
                        maxLines: null,
                        expands: true,
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Ctrl + Enter",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: viewModel.check,
                            icon: const Icon(Icons.spellcheck),
                            label: Text(locale.check),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right: Result Card
          Expanded(
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (viewModel.prompt != null)
                        AIMarkdown(
                          prompt: viewModel.prompt!,
                          onResult: (outputText) {
                            viewModel.saveResult(outputText);
                          },
                        ),
                      if (viewModel.outputText != null)
                        SelectionArea(
                          onSelectionChanged: context
                              .read<SelectionTextViewModel>()
                              .setSelectedText,
                          contextMenuBuilder: buildCustomContextMenu(
                            fallbackText: viewModel.outputText!,
                          ),
                          child: GptMarkdown(viewModel.outputText!),
                        ),
                      if (viewModel.prompt == null &&
                          viewModel.outputText == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 32.0),
                          child: Center(
                            child: Text(
                              locale.empty,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

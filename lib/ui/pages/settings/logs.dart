import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/logs_view_model.dart";
import "package:flutter/material.dart";
import "package:logger/logger.dart";
import "package:provider/provider.dart";

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  Color _getLogColor(Level level, BuildContext context) {
    final brightness = Theme.of(context).brightness;
    switch (level) {
      case Level.debug:
        return Colors.blue;
      case Level.warning:
        return Colors.orange;
      case Level.error:
      case Level.fatal:
        return Colors.red;
      case Level.info:
      default:
        return brightness == Brightness.dark ? Colors.white : Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LogsViewModel(),
      child: Consumer<LogsViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: viewModel.isMultiSelectMode
                ? AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: viewModel.clearSelection,
                    ),
                    title: Text("${viewModel.selectedIndices.length} selected"),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => viewModel.copySelectedLogs(context),
                      ),
                    ],
                  )
                : AppBar(
                    title: Text(AppLocalizations.of(context)!.logs),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.copy_all_outlined),
                        onPressed: () => viewModel.copyAllLogs(context),
                      ),
                    ],
                  ),
            body: ListView.builder(
              itemCount: viewModel.logs.length,
              itemBuilder: (context, index) {
                final log = viewModel.logs.elementAt(index);
                final logText = log.lines.join("\n");

                return ListTile(
                  selectedTileColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  title: Text(
                    logText,
                    style: TextStyle(color: _getLogColor(log.level, context)),
                  ),
                  selected: viewModel.selectedIndices.contains(index),
                  onTap: () {
                    if (viewModel.isMultiSelectMode) {
                      viewModel.toggleSelection(index);
                    } else {
                      viewModel.copyLog(context, logText);
                    }
                  },
                  onLongPress: () => viewModel.toggleSelection(index),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:flutter/material.dart";
import "package:logger/logger.dart";

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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.logs),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              final allLogs = loggerOutput.buffer
                  .map((log) => log.lines.join("\n"))
                  .join("\n\n");
              addToClipboard(context, allLogs);
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: loggerOutput.buffer.length,
        itemBuilder: (context, index) {
          final log = loggerOutput.buffer.elementAt(index);
          final logText = log.lines.join("\n");

          return ListTile(
            title: Text(
              logText,
              style: TextStyle(color: _getLogColor(log.level, context)),
            ),
            onTap: () => addToClipboard(context, logText),
          );
        },
      ),
    );
  }
}

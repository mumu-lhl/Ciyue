import "package:ciyue/core/app_globals.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";
import "package:talker_flutter/talker_flutter.dart";

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return TalkerScreen(
      appBarTitle: AppLocalizations.of(context)!.logs,
      talker: talker,
      // talker_flutter still imports package:flutter/material.dart, so its
      // ThemeData is a different type from material_ui's ThemeData.
      theme: TalkerScreenTheme(
        backgroundColor: theme.colorScheme.surface,
        textColor: theme.colorScheme.onSurface,
        cardColor: theme.colorScheme.surface,
      ),
    );
  }
}

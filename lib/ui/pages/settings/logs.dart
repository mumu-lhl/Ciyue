import "package:ciyue/core/app_globals.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";
import "package:talker_flutter/talker_flutter.dart";

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return TalkerScreen(
      appBarTitle: AppLocalizations.of(context)!.logs,
      talker: talker,
      theme: TalkerScreenTheme.fromTheme(Theme.of(context)),
    );
  }
}

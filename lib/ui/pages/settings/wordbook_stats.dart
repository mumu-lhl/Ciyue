import "package:ciyue/core/app_globals.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/stats_calendar.dart";
import "package:ciyue/viewModels/open_record_stats_viewmodel.dart";
import "package:ciyue/viewModels/wordbook_stats_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class WordbookStatsPage extends StatelessWidget {
  const WordbookStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => WordbookStatsViewModel(mainDatabase.wordbookDao),
        ),
        ChangeNotifierProvider(
          create: (context) => OpenRecordStatsViewModel(context.read()),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.wordbookStats),
        ),
        body: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                AppLocalizations.of(context)!.wordbookStats,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const StatsCalendar<WordbookStatsViewModel>(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                AppLocalizations.of(context)!.openRecordStats,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const StatsCalendar<OpenRecordStatsViewModel>(),
          ],
        ),
      ),
    );
  }
}

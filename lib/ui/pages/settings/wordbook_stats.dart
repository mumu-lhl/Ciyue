import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/open_records.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/stats_calendar.dart";
import "package:ciyue/viewModels/open_record_stats_viewmodel.dart";
import "package:ciyue/viewModels/wordbook_stats_view_model.dart";
import "package:material_ui/material_ui.dart";

class WordbookStatsPage extends StatefulWidget {
  const WordbookStatsPage({super.key});

  @override
  State<WordbookStatsPage> createState() => _WordbookStatsPageState();
}

class _WordbookStatsPageState extends State<WordbookStatsPage> {
  late final WordbookStatsViewModel _wordbookStats;
  late final OpenRecordStatsViewModel _openRecordStats;

  @override
  void initState() {
    super.initState();
    _wordbookStats = WordbookStatsViewModel(mainDatabase.wordbookDao);
    _openRecordStats = OpenRecordStatsViewModel(OpenRecordsRepository());
  }

  @override
  void dispose() {
    _wordbookStats.dispose();
    _openRecordStats.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.wordbookStats)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  AppLocalizations.of(context)!.wordbookStats,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatsCalendar(viewModel: _wordbookStats),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  AppLocalizations.of(context)!.openRecordStats,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatsCalendar(viewModel: _openRecordStats),
            ],
          ),
        ),
      ),
    );
  }
}

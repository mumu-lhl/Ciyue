import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/history.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

void main() {
  testWidgets("history settings page shows the history title", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<HistoryModel>(
          create: (_) => _FakeHistoryModel(),
          child: const HistorySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("History"), findsOneWidget);
    expect(find.text("About"), findsNothing);
  });
}

class _FakeHistoryModel extends HistoryModel {
  @override
  bool get enableHistory => true;

  @override
  Future<void> loadHistory() async {
    setHistory([]);
  }
}

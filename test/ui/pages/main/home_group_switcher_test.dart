import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/main/home/group_switcher.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

void main() {
  testWidgets("home group switcher displays the active group", (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DictManagerModel(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeGroupSwitcher()),
        ),
      ),
    );

    expect(find.text("Dictionary group: Default"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

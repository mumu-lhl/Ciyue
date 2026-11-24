import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/lookup_popup/lookup_bubble_page.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  testWidgets("bubble button calls onTap", (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LookupBubblePage(onTap: () => tapped = true),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final button = find.byKey(const ValueKey("lookup_bubble_button"));
    expect(button, findsOneWidget);
    expect(tester.widget<IconButton>(button).tooltip, "Lookup");

    await tester.tap(button);
    expect(tapped, isTrue);
  });
}

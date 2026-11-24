import "package:ciyue/services/lookup_popup.dart";
import "package:ciyue/ui/core/lookup_popup_host.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  testWidgets("the host builds in the startup splash before prefs are loaded", (
    tester,
  ) async {
    // main() mounts this host around the splash before initApp() has read the
    // preferences, so no initPrefs() here on purpose: the host must not touch
    // the settings provider until a popup is actually requested.
    await tester.pumpWidget(
      ProviderScope(
        child: LookupPopupHost(
          service: LookupPopupService(),
          child: const MaterialApp(home: Text("splash")),
        ),
      ),
    );

    expect(find.text("splash"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

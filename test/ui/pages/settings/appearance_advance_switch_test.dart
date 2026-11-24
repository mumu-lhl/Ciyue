import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/appearance.dart";
import "package:ciyue/ui/pages/settings/appearance/drawer_icon_switch.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  setUp(() async {
    await settings.setAdvance(false);
  });

  testWidgets("the advance switch reveals its card without leaving the page", (
    tester,
  ) async {
    // Tall enough that the whole page is built and on screen: the switch and
    // the card it reveals are both below the short default viewport.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppearanceSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DrawerIconSwitch), findsNothing);

    await tester.tap(find.text("Advance"));
    await tester.pumpAndSettle();

    expect(settings.advance, isTrue);
    expect(find.byType(DrawerIconSwitch), findsOneWidget);
  });
}

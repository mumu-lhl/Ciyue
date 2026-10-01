import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/appearance/dictionary_background_color.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
    refreshAll = () {};
  });

  testWidgets("selected background color appears in the settings tile", (
    tester,
  ) async {
    await settings.setDictionaryBackgroundColor(null);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: DictionaryBackgroundColor()),
        ),
      ),
    );

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    final whiteSwatch = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color == Colors.white,
    );
    expect(whiteSwatch, findsOneWidget);
    await tester.tap(whiteSwatch);
    await tester.pumpAndSettle();

    final selectedColorDot = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color == Colors.white,
    );
    expect(selectedColorDot, findsOneWidget);
  });

  testWidgets("custom background picker offers HSV and RGB controls", (
    tester,
  ) async {
    await settings.setDictionaryBackgroundColor(null);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: DictionaryBackgroundColor()),
        ),
      ),
    );

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Custom"));
    await tester.pumpAndSettle();

    expect(find.text("HSV"), findsOneWidget);
    expect(find.text("RGB"), findsOneWidget);
  });
}

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/other.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool Function() savedWatcherAvailable;
  late bool Function() savedModifierTriggerAvailable;

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    // No allow list: Settings reads the whole preference set.
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    savedWatcherAvailable = isLookupBubbleWatcherAvailable;
    savedModifierTriggerAvailable = isLookupBubbleModifierTriggerAvailable;
  });

  setUp(() async {
    await SharedPreferencesAsync().clear();
    await prefs.reloadCache();
    await settings.setEnableLookupHotkey(false);
    await settings.setLookupHotkeyChord("");
    await settings.setEnableLookupBubble(true);
    await settings.setLookupBubbleTrigger("selection");
    await settings.setLookupBubbleModifier("control");
    await settings.setLookupExcludedApps([]);
    isLookupBubbleWatcherAvailable = savedWatcherAvailable;
    isLookupBubbleModifierTriggerAvailable = savedModifierTriggerAvailable;
  });

  tearDown(() {
    isLookupBubbleWatcherAvailable = savedWatcherAvailable;
    isLookupBubbleModifierTriggerAvailable = savedModifierTriggerAvailable;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: LookupPopupSettings()),
      ),
    );
    await tester.pumpAndSettle();
  }

  SwitchListTile bubbleSwitch(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.byKey(const Key("lookupBubbleSwitch")));

  group("LookupPopupSettings bubble section", () {
    testWidgets("hides the trigger when no watcher exists", (tester) async {
      isLookupBubbleWatcherAvailable = () => false;
      await pumpSettings(tester);

      expect(bubbleSwitch(tester).value, isFalse);
      expect(bubbleSwitch(tester).onChanged, isNull);
      expect(
        find.byKey(const Key("lookupBubbleTriggerDropdown")),
        findsNothing,
      );
    });

    testWidgets("shows the trigger when a watcher exists", (tester) async {
      isLookupBubbleWatcherAvailable = () => true;
      await pumpSettings(tester);

      expect(bubbleSwitch(tester).value, isTrue);
      expect(bubbleSwitch(tester).onChanged, isNotNull);
      expect(
        find.byKey(const Key("lookupBubbleTriggerDropdown")),
        findsOneWidget,
      );
    });

    testWidgets("omits the modifier trigger and says why off X11", (
      tester,
    ) async {
      isLookupBubbleWatcherAvailable = () => true;
      isLookupBubbleModifierTriggerAvailable = () => false;
      await pumpSettings(tester);

      expect(
        find.text("The modifier trigger needs X11; it never fires on Wayland."),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key("lookupBubbleTriggerDropdown")));
      await tester.pumpAndSettle();
      expect(find.text("Any selection"), findsWidgets);
      expect(find.text("Modifier key held"), findsNothing);
      // The double-click trigger needs no X11 modifier state, so it stays
      // offered even where the modifier trigger is hidden.
      expect(find.text("Double-click to select"), findsOneWidget);
    });

    testWidgets("offers the modifier trigger on X11", (tester) async {
      isLookupBubbleWatcherAvailable = () => true;
      isLookupBubbleModifierTriggerAvailable = () => true;
      await pumpSettings(tester);

      expect(
        find.text("The modifier trigger needs X11; it never fires on Wayland."),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key("lookupBubbleTriggerDropdown")));
      await tester.pumpAndSettle();
      expect(find.text("Any selection"), findsWidgets);
      expect(find.text("Modifier key held"), findsOneWidget);
      expect(find.text("Double-click to select"), findsOneWidget);
    });

    testWidgets("selecting double-click persists the trigger", (tester) async {
      isLookupBubbleWatcherAvailable = () => true;
      isLookupBubbleModifierTriggerAvailable = () => true;
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key("lookupBubbleTriggerDropdown")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Double-click to select"));
      await tester.pumpAndSettle();
      expect(settings.lookupBubbleTrigger, "doubleClick");
      expect(find.text("Double-click to select"), findsOneWidget);
    });
  });
}

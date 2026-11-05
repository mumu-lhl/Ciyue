import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/main/home/body.dart";
import "package:ciyue/ui/pages/main/home/search.dart";
import "package:ciyue/ui/pages/settings/appearance/search_pane_switch.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

class _TestHistoryModel extends HistoryModel {
  @override
  Future<void> loadHistory() async {}
}

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  setUp(() async {
    // Every test starts with the pane shown; the Settings singleton is
    // shared across tests in this file.
    await prefs.setBool("showSearchPane", true);
    settings.showSearchPane = true;
  });

  Future<void> pumpHomeBody(
    WidgetTester tester, {
    required Size surfaceSize,
    required HomeModel homeModel,
  }) async {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(homeModel.searchController.dispose);
    addTearDown(homeModel.searchBarFocusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeModelProvider.overrideWith((ref) => homeModel),
          historyModelProvider.overrideWith((ref) => _TestHistoryModel()),
          dictManagerModelProvider.overrideWith((ref) => DictManagerModel()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group("search pane collapse", () {
    testWidgets("tab bar toggle hides and restores the search pane", (
      tester,
    ) async {
      final homeModel = HomeModel();
      await pumpHomeBody(
        tester,
        surfaceSize: const Size(1280, 800),
        homeModel: homeModel,
      );

      expect(find.byType(HomeSearchBar), findsOneWidget);

      // The toggle lives in the tab bar, so open a tab first.
      homeModel.newTab();
      await tester.pumpAndSettle();
      expect(find.byType(HomeSearchBar), findsOneWidget);

      await tester.tap(find.byTooltip("Hide Search Pane"));
      await tester.pumpAndSettle();
      expect(find.byType(HomeSearchBar), findsNothing);
      // The tab bar itself stays, so the pane can be expanded again.
      expect(find.byTooltip("New Tab (Ctrl+T)"), findsOneWidget);

      await tester.tap(find.byTooltip("Show Search Pane"));
      await tester.pumpAndSettle();
      expect(find.byType(HomeSearchBar), findsOneWidget);
    });

    testWidgets("collapsed pane stays collapsed across a rebuild", (
      tester,
    ) async {
      final homeModel = HomeModel();
      await pumpHomeBody(
        tester,
        surfaceSize: const Size(1280, 800),
        homeModel: homeModel,
      );
      homeModel.newTab();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip("Hide Search Pane"));
      await tester.pumpAndSettle();
      expect(find.byType(HomeSearchBar), findsNothing);
      expect(prefs.getBool("showSearchPane"), isFalse);

      // Rebuild the whole tree from scratch: the pane must follow the
      // persisted pref, not any widget-local state.
      final freshHomeModel = HomeModel();
      await pumpHomeBody(
        tester,
        surfaceSize: const Size(1280, 800),
        homeModel: freshHomeModel,
      );
      expect(find.byType(HomeSearchBar), findsNothing);
    });

    test("showSearchPane round-trips through SharedPreferences", () async {
      await prefs.setBool("showSearchPane", false);
      expect(Settings().showSearchPane, isFalse);

      await prefs.setBool("showSearchPane", true);
      expect(Settings().showSearchPane, isTrue);
    });
  });

  group("portrait layout", () {
    testWidgets("portrait tablet shows the mobile layout, not the split view", (
      tester,
    ) async {
      // Wide enough to count as a large screen, but portrait.
      //
      // Pumped inside runAsync on purpose: the mobile column contains
      // BottomSearchBar, whose loading poll (Future.delayed loop) never
      // exits while the global dictManager stays loading in tests. As a
      // fake-async timer it would still be pending at teardown and trip the
      // test framework's timer invariant; as a real timer it is invisible
      // to that check and never calls setState (the loop only exits when
      // loading finishes, which never happens here).
      await tester.runAsync(() async {
        await pumpHomeBody(
          tester,
          surfaceSize: const Size(800, 1280),
          homeModel: HomeModel(),
        );
      });

      expect(find.byType(BottomSearchBar), findsOneWidget);
      expect(find.byType(HomeSearchBar), findsNothing);
    });

    testWidgets("landscape tablet shows the split view with the search pane", (
      tester,
    ) async {
      await pumpHomeBody(
        tester,
        surfaceSize: const Size(1280, 800),
        homeModel: HomeModel(),
      );

      expect(find.byType(HomeSearchBar), findsOneWidget);
      expect(find.byType(BottomSearchBar), findsNothing);
    });
  });

  group("SearchPaneSwitch", () {
    testWidgets("settings switch toggles the persisted pref", (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SearchPaneSwitch()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Show Search Pane"), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(prefs.getBool("showSearchPane"), isFalse);
      expect(settings.showSearchPane, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(prefs.getBool("showSearchPane"), isTrue);
      expect(settings.showSearchPane, isTrue);
    });
  });
}

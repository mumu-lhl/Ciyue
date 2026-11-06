import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/main/home/app_bar.dart";
import "package:ciyue/ui/pages/main/home/body.dart";
import "package:ciyue/ui/pages/main/home/more_button.dart";
import "package:ciyue/ui/pages/main/home_top_nav_bar.dart";
import "package:ciyue/utils.dart";
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

const _destinations = <(Icon, String)>[
  (Icon(Icons.home), "Home"),
  (Icon(Icons.translate), "Translate"),
  (Icon(Icons.book), "Word Book"),
  (Icon(Icons.settings), "Settings"),
];

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  Future<void> setSurface(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group("useDesktopLayout", () {
    Future<bool> measure(WidgetTester tester, Size size) async {
      await setSurface(tester, size);
      var result = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = useDesktopLayout(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets("wide landscape windows opt in", (tester) async {
      expect(await measure(tester, const Size(1280, 800)), isTrue);
    });

    testWidgets("portrait tablets keep the compact layout", (tester) async {
      expect(await measure(tester, const Size(800, 1280)), isFalse);
    });

    testWidgets("phones keep the compact layout", (tester) async {
      expect(await measure(tester, const Size(390, 844)), isFalse);
    });

    testWidgets("landscape phones still use the existing split view", (
      tester,
    ) async {
      // Same rule HomeBody had before this change: a landscape phone is wide
      // enough for the split view, but must not get the top navigation row.
      expect(await measure(tester, const Size(844, 390)), isTrue);
    });
  });

  group("useTopNavBar", () {
    Future<bool> measure(WidgetTester tester, Size size) async {
      await setSurface(tester, size);
      var result = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = useTopNavBar(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets("wide landscape windows opt in", (tester) async {
      expect(await measure(tester, const Size(1280, 800)), isTrue);
    });

    testWidgets("the screenshot-sized window opts in", (tester) async {
      expect(await measure(tester, const Size(1080, 590)), isTrue);
    });

    testWidgets("the default desktop window keeps the rail", (tester) async {
      expect(await measure(tester, const Size(800, 600)), isFalse);
    });

    testWidgets("landscape phones keep the rail", (tester) async {
      expect(await measure(tester, const Size(844, 390)), isFalse);
    });

    testWidgets("portrait tablets keep the bottom navigation bar", (
      tester,
    ) async {
      expect(await measure(tester, const Size(800, 1280)), isFalse);
    });
  });

  group("HomeTopNavBar", () {
    Future<void> pumpBar(
      WidgetTester tester, {
      required Size size,
      required ValueChanged<int> onSelected,
    }) async {
      await setSurface(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: HomeTopNavBar(
              currentIndex: 0,
              destinations: _destinations,
              onDestinationSelected: onSelected,
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("shows four destinations and one global chat entry", (
      tester,
    ) async {
      final selected = <int>[];
      await pumpBar(
        tester,
        size: const Size(1280, 800),
        onSelected: selected.add,
      );

      expect(find.text("Translate"), findsOneWidget);
      expect(find.text("Settings"), findsOneWidget);
      expect(find.byTooltip("AI Chat"), findsOneWidget);

      await tester.tap(find.text("Translate"));
      await tester.pumpAndSettle();
      expect(selected, [1]);
    });

    testWidgets("narrow large-screen windows fall back to icon-only entries", (
      tester,
    ) async {
      await pumpBar(tester, size: const Size(700, 600), onSelected: (_) {});
      expect(find.text("Translate"), findsNothing);
      expect(find.byTooltip("Translate"), findsOneWidget);
    });
  });

  group("navigation style toggle", () {
    testWidgets("top bar button asks for the side navigation", (tester) async {
      await setSurface(tester, const Size(1280, 800));
      var toggled = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: HomeTopNavBar(
              currentIndex: 0,
              destinations: _destinations,
              onDestinationSelected: (_) {},
              onToggleNavStyle: () => toggled++,
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip("Switch to side navigation"), findsOneWidget);
      await tester.tap(find.byTooltip("Switch to side navigation"));
      await tester.pumpAndSettle();
      expect(toggled, 1);
    });
  });

  group("chat tooltips", () {
    testWidgets("global and word-scoped chat have different wordings", (
      tester,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.aiChat, "AI Chat");
      expect(l10n.askAboutWord("spiel"), 'Ask AI about "spiel"');
      expect(l10n.aiChat, isNot(l10n.askAboutWord("spiel")));
    });
  });

  group("HomeAppBar outside the top navigation layout", () {
    Future<void> pumpAppBar(WidgetTester tester, Size size) async {
      await setSurface(tester, size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyModelProvider.overrideWith((ref) => _TestHistoryModel()),
            dictManagerModelProvider.overrideWith((ref) => DictManagerModel()),
          ],
          child: MaterialApp(
            locale: const Locale("en"),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(appBar: HomeAppBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("split view leaves group and more to the word tab bar", (
      tester,
    ) async {
      await pumpAppBar(tester, const Size(800, 600));
      expect(find.byType(GroupSelectorButton), findsNothing);
      expect(find.byType(MoreButton), findsNothing);
      // The general chat entry stays in the top row.
      expect(find.byTooltip("AI Chat"), findsOneWidget);
    });

    testWidgets("compact layout keeps its group and more buttons", (
      tester,
    ) async {
      await pumpAppBar(tester, const Size(800, 1280));
      expect(find.byType(GroupSelectorButton), findsOneWidget);
      expect(find.byType(MoreButton), findsOneWidget);
    });
  });

  group("split view tab bar", () {
    Future<void> pumpHomeBody(WidgetTester tester) async {
      await setSurface(tester, const Size(1280, 800));
      final homeModel = HomeModel();
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
            locale: const Locale("en"),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: HomeBody()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("stays without tabs and hosts the home-wide controls", (
      tester,
    ) async {
      await pumpHomeBody(tester);
      expect(find.byTooltip("New Tab (Ctrl+T)"), findsOneWidget);
      expect(find.byType(GroupSelectorButton), findsOneWidget);
      expect(find.byType(MoreButton), findsOneWidget);
    });
  });
}

import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
import "package:ciyue/ui/pages/main/home/body.dart";
import "package:ciyue/ui/pages/main/home/search.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
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

  test("buildTitle forwards the word-selected callback", () {
    settings.showSearchBarInWordDisplay = true;
    final controller = SearchController();
    addTearDown(controller.dispose);

    final bar =
        buildTitle(
              "with",
              settings,
              controller: controller,
              onWordSelected: (_) {},
            )!
            as WordSearchBarWithSuggestions;

    expect(bar.onWordSelected, isNotNull);
  });

  testWidgets("split view search box opens the word in a new tab", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final homeModel = HomeModel();
    addTearDown(homeModel.searchController.dispose);
    addTearDown(homeModel.searchBarFocusNode.dispose);
    homeModel.ensureInitialWord("with");

    final router = GoRouter(
      routes: [
        GoRoute(
          path: "/",
          builder: (context, state) => const Scaffold(body: HomeBody()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeModelProvider.overrideWith((ref) => homeModel),
          historyModelProvider.overrideWith((ref) => _TestHistoryModel()),
          dictManagerModelProvider.overrideWith((ref) => DictManagerModel()),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<HomeSearchBar>(find.byType(HomeSearchBar));
    expect(bar.onWordSelected, isNotNull);
    expect(homeModel.tabs.length, 1);

    bar.onWordSelected!("hello");
    await tester.pumpAndSettle();

    expect(homeModel.tabs.length, 2);
    expect(homeModel.selectedWord, "hello");
  });

  testWidgets("empty new tab keeps a search box when the pane is collapsed", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    settings.showSearchPane = true;

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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The left pane and the empty state each own a search box; the latter
    // uses its own SearchController so they never share an anchor.
    expect(find.byType(WordSearchBarWithSuggestions), findsNWidgets(2));

    await tester.tap(find.byTooltip("Hide Search Pane"));
    await tester.pumpAndSettle();

    expect(find.byType(HomeSearchBar), findsNothing);
    expect(find.byType(WordSearchBarWithSuggestions), findsOneWidget);
  });
}

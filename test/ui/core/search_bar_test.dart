import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  testWidgets("home search clears submitted text when auto-remove is enabled", (
    tester,
  ) async {
    settings.autoRemoveSearchWord = true;
    final controller = SearchController();
    addTearDown(controller.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: "/",
          builder: (context, state) => Scaffold(
            body: WordSearchBarWithSuggestions(
              word: "apple",
              controller: controller,
              isHome: true,
            ),
          ),
        ),
        GoRoute(
          path: "/word/:word",
          builder: (context, state) =>
              Scaffold(body: Text("opened:${state.pathParameters["word"]}")),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HistoryModel>(
            create: (_) => _TestHistoryModel(),
          ),
          ChangeNotifierProvider(create: (_) => DictManagerModel()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.byType(SearchBar));
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text("opened:apple"), findsOneWidget);
    expect(controller.text, "");
  });

  testWidgets(
    "search bar selects all text on open and does not refill text when cleared while view is open",
    (tester) async {
      final controller = SearchController();
      addTearDown(controller.dispose);

      Widget buildHost({required String word}) {
        return ChangeNotifierProvider(
          create: (_) => DictManagerModel(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: WordSearchBarWithSuggestions(
                word: word,
                controller: controller,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHost(word: "apple"));
      expect(controller.text, "apple");

      // Tap the search bar to open view
      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);

      // Verify text is selected on open (Issue #420 recommendation)
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );

      // Tap clear ("X") button
      final clearButton = find.byTooltip("Clear text");
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pump();
      expect(controller.text, "");

      // Rebuild occurs (simulating async dictionary loading completion or parent rebuild)
      await tester.pumpWidget(buildHost(word: "apple"));
      await tester.pump();

      // Controller text should remain empty while the view is open (Issue #420 bug fix)
      expect(
        controller.text,
        "",
        reason: "Controller text must not be overwritten while view is open",
      );

      // Close the view without searching
      controller.closeView(null);
      await tester.pumpAndSettle();

      // After closing, the search bar restores the word for the current page
      expect(controller.text, "apple");
    },
  );
}

class _TestHistoryModel extends HistoryModel {
  @override
  void addHistory(String word) {}

  @override
  Future<void> loadHistory() async {}
}

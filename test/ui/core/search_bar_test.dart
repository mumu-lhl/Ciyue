import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
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
      ProviderScope(
        overrides: [
          historyModelProvider.overrideWith((ref) => _TestHistoryModel()),
          dictManagerModelProvider.overrideWith((ref) => DictManagerModel()),
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
        return ProviderScope(
          overrides: [
            dictManagerModelProvider.overrideWith((ref) => DictManagerModel()),
          ],
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

      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);

      // Verify text is selected on open (Issue #420 recommendation)
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );

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

      controller.closeView(null);
      await tester.pumpAndSettle();

      expect(controller.text, "apple");
    },
  );

  testWidgets("suggestions offer full-text search and navigate to its page", (
    tester,
  ) async {
    settings.enableHunspellMorphology = false;
    final controller = SearchController();
    addTearDown(controller.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: "/",
          builder: (context, state) => Scaffold(
            body: WordSearchBarWithSuggestions(
              word: "",
              controller: controller,
              isHome: true,
            ),
          ),
        ),
        GoRoute(
          path: "/full-text-search",
          builder: (context, state) =>
              Scaffold(body: Text("fts:${state.uri.queryParameters["query"]}")),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictManagerModelProvider.overrideWith((ref) => DictManagerModel()),
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
    controller.text = "apple";
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    final tile = find.text("Search in definitions: apple");
    expect(tile, findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text("fts:apple"), findsOneWidget);
  });

  testWidgets(
    "a burst of keystrokes only queries the last text (cancellable Timer)",
    (tester) async {
      // The debounce is a Timer, not a Future.delayed: a keystroke that
      // arrives inside the 100 ms window must cancel the pending query
      // before it starts, not merely throw its result away after it ran.
      settings.enableHunspellMorphology = false;
      final dictionary = _CountingMdict();
      dictManager.dictIds = [1];
      dictManager.dicts[1] = dictionary;
      dictManager.markLoaded();
      addTearDown(() {
        dictManager.dicts.clear();
        dictManager.dictIds = [];
      });

      final controller = SearchController();
      addTearDown(controller.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: "/",
            builder: (context, state) => Scaffold(
              body: WordSearchBarWithSuggestions(
                word: "",
                controller: controller,
                isHome: true,
              ),
            ),
          ),
          GoRoute(
            path: "/full-text-search",
            builder: (context, state) => const Scaffold(body: Text("fts")),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dictManagerModelProvider.overrideWith((ref) => DictManagerModel()),
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

      controller.text = "app";
      await tester.pump(const Duration(milliseconds: 50));
      controller.text = "apple";
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Only the last keystroke ran: one query, which searches both width
      // variants ("apple" then "ａｐｐｌｅ"), so two calls in total.
      expect(dictionary.searchCalls, 2);
      expect(dictionary.lastQuery, "ａｐｐｌｅ");
      expect(find.text("Search in definitions: apple"), findsOneWidget);
    },
  );
}

class _CountingMdict extends Mdict {
  // `id` is a `late` field on Mdict: the suggestion pipeline reads it for
  // the prefix-cache fingerprint, so a fake that leaves it unset throws a
  // LateInitializationError (swallowed by the debounce's catch) and the
  // query never reaches `search`.
  _CountingMdict() : super(path: "unused") {
    id = 1;
  }

  int searchCalls = 0;
  String? lastQuery;

  @override
  bool get isReady => true;

  @override
  Future<List<String>> search(String query) async {
    searchCalls++;
    lastQuery = query;
    return const [];
  }

  @override
  Future<String?> resolveExactKey(String word) async => null;

  @override
  Future<Map<String, String>> resolveKeys(Iterable<String> words) async =>
      const {};

  @override
  Future<List<DictionaryEntryData>> readExactEntries(
    Iterable<String> words, {
    Map<String, String>? resolvedKeys,
  }) async => const [];
}

class _TestHistoryModel extends HistoryModel {
  @override
  void addHistory(String word) {}

  @override
  Future<void> loadHistory() async {}
}

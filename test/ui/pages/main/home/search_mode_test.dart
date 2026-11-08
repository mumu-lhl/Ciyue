import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/search_mode.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/full_text_index_builder.dart";
import "package:ciyue/services/full_text_index_store.dart";
import "package:ciyue/services/full_text_search_service.dart";
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

class _TestHistoryModel extends HistoryModel {
  @override
  void addHistory(String word) {}

  @override
  Future<void> loadHistory() async {}
}

class _FtsFakeDictionary implements LoadedDictionary {
  @override
  final int id;
  @override
  final int type;
  @override
  final String path;

  _FtsFakeDictionary({
    required this.id,
    required this.type,
    required this.path,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Real FTS services over canned rows, built once in setUpAll: file I/O
  // and Drift awaits never complete inside a testWidgets body (FakeAsync
  // zone), so no fixture setup may live in the test bodies below. Each
  // service is used by exactly one widget test, so the ProviderScope that
  // overrides with it also owns disposing it.
  late Directory fullTextDir;
  late FullTextSearchService fullTextService;
  late Directory suffixDir;
  late FullTextSearchService suffixService;

  Future<FullTextSearchService> buildService(
    Directory dir,
    List<FullTextIndexRow> rows,
  ) async {
    final mdxFile = File("${dir.path}/dict.mdx");
    await mdxFile.writeAsBytes([1, 2, 3, 4]);
    final dictionary = _FtsFakeDictionary(
      id: 1,
      type: 1,
      path: "${dir.path}/dict",
    );
    final service = FullTextSearchService(
      dictionaries: () => [dictionary],
      knownIds: () async => {1},
      databaseDirectory: () async => dir.path,
      runner:
          (
            FullTextBuildRequest request, {
            required Future<void> Function(List<FullTextIndexRow>, int, int)
            onBatch,
            required Future<void> Function(int) onTotal,
            required FullTextBuildCancelToken cancelToken,
          }) async {
            await onTotal(rows.length);
            for (final row in rows) {
              await onBatch([row], row.rowid, rows.length);
            }
          },
    );
    await service.ensureBuilt(dictionary);
    return service;
  }

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();

    fullTextDir = await Directory.systemTemp.createTemp("search_mode_bar_");
    fullTextService = await buildService(fullTextDir, const [
      FullTextIndexRow(rowid: 1, headword: "中国", body: "中国是一个国家"),
      FullTextIndexRow(rowid: 2, headword: "中华民国", body: "历史上的国家"),
      FullTextIndexRow(rowid: 3, headword: "中华人民共和国", body: "成立于1949年"),
      FullTextIndexRow(rowid: 4, headword: "美国", body: "美利坚合众国"),
    ]);
    expect(fullTextService.stateFor(1).status, FullTextIndexStatus.ready);

    suffixDir = await Directory.systemTemp.createTemp("search_mode_bar2_");
    suffixService = await buildService(suffixDir, const [
      FullTextIndexRow(rowid: 1, headword: "社会主义", body: "一种社会制度"),
      FullTextIndexRow(rowid: 2, headword: "主义者", body: "信奉某种主义的人"),
      FullTextIndexRow(rowid: 3, headword: "马克思主义", body: "一种理论"),
    ]);
    expect(suffixService.stateFor(1).status, FullTextIndexStatus.ready);
  });

  tearDownAll(() async {
    await fullTextDir.delete(recursive: true);
    await suffixDir.delete(recursive: true);
  });

  setUp(() {
    // Every test starts in prefix mode; the Settings singleton is shared
    // across tests in this file.
    settings.searchMode = SearchMode.prefix;
  });

  test("searchMode round-trips through SharedPreferences", () async {
    await prefs.setString("searchMode", "suffix");
    expect(Settings().searchMode, SearchMode.suffix);

    await prefs.setString("searchMode", "multiWord");
    expect(Settings().searchMode, SearchMode.multiWord);

    await prefs.setString("searchMode", "fullText");
    expect(Settings().searchMode, SearchMode.fullText);

    // An unknown stored value falls back to prefix, never throws.
    await prefs.setString("searchMode", "bogus");
    expect(Settings().searchMode, SearchMode.prefix);

    await prefs.remove("searchMode");
    expect(Settings().searchMode, SearchMode.prefix);
  });

  test("setSearchMode persists the mode and notifies", () async {
    await settings.setSearchMode(SearchMode.suffix);
    expect(prefs.getString("searchMode"), "suffix");
    expect(settings.searchMode, SearchMode.suffix);
  });

  group("search bar mode button", () {
    Future<void> pumpBar(
      WidgetTester tester, {
      required SearchController controller,
      required GoRouter router,
    }) async {
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
      await tester.pumpAndSettle();
    }

    GoRouter buildRouter(SearchController controller) {
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
            path: "/word/:word",
            builder: (context, state) =>
                Scaffold(body: Text("opened:${state.pathParameters["word"]}")),
          ),
          GoRoute(
            path: "/full-text-search",
            builder: (context, state) => Scaffold(
              body: Text("fts:${state.uri.queryParameters["query"]}"),
            ),
          ),
        ],
      );
      return router;
    }

    testWidgets("cycles prefix -> suffix -> multi-word -> full text", (
      tester,
    ) async {
      final controller = SearchController();
      addTearDown(controller.dispose);
      final router = buildRouter(controller);
      addTearDown(router.dispose);

      await pumpBar(tester, controller: controller, router: router);

      expect(find.byTooltip("Search mode: Prefix"), findsOneWidget);
      expect(find.byIcon(Icons.first_page), findsOneWidget);

      await tester.tap(find.byTooltip("Search mode: Prefix"));
      await tester.pumpAndSettle();
      expect(find.byTooltip("Search mode: Suffix"), findsOneWidget);
      expect(prefs.getString("searchMode"), "suffix");

      await tester.tap(find.byTooltip("Search mode: Suffix"));
      await tester.pumpAndSettle();
      expect(find.byTooltip("Search mode: Multi-word"), findsOneWidget);
      expect(prefs.getString("searchMode"), "multiWord");

      await tester.tap(find.byTooltip("Search mode: Multi-word"));
      await tester.pumpAndSettle();
      expect(find.byTooltip("Search mode: Full text"), findsOneWidget);
      expect(prefs.getString("searchMode"), "fullText");

      await tester.tap(find.byTooltip("Search mode: Full text"));
      await tester.pumpAndSettle();
      expect(find.byTooltip("Search mode: Prefix"), findsOneWidget);
      expect(prefs.getString("searchMode"), "prefix");
    });

    testWidgets("full-text mode shows definition hits in the bar", (
      tester,
    ) async {
      // A real service over canned rows (built in setUpAll), so the bar's
      // FTS path is exercised end to end without a dictionary file.
      // The whole interaction runs inside runAsync: the suggestion builder
      // awaits a drift query, which never completes in fake time (same
      // FakeAsync trap as file I/O), so the query must run on the real
      // event loop. The debounce is then real time too, hence the
      // Future.delayed below instead of a fake-time pump.
      // Note the query is "国家", not "中国": full-text search matches the
      // adjacent phrase, so "中国" would only ever hit the 中国 entry
      // itself. The non-adjacent "中国" acceptance case belongs to
      // multi-word AND mode, covered at the lookup level.
      settings.searchMode = SearchMode.fullText;
      final controller = SearchController();
      addTearDown(controller.dispose);
      final router = buildRouter(controller);
      addTearDown(router.dispose);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              historyModelProvider.overrideWith((ref) => _TestHistoryModel()),
              dictManagerModelProvider.overrideWith(
                (ref) => DictManagerModel(),
              ),
              fullTextSearchServiceProvider.overrideWith(
                (ref) => fullTextService,
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(SearchBar));
        await tester.pumpAndSettle();
        controller.text = "国家";
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
      });

      // The tile below the hits is built after the same query, so it also
      // proves the suggestion builder ran to completion.
      expect(find.text("Search in definitions: 国家"), findsOneWidget);
      // Definition hits in the bar itself: both entries whose body
      // contains 国家; the others do not mention it.
      expect(find.text("中国"), findsWidgets);
      expect(find.text("中华民国"), findsOneWidget);
      expect(find.text("中华人民共和国"), findsNothing);
      expect(find.text("美国"), findsNothing);

      // Tapping a hit opens the exact headword, like any other suggestion.
      await tester.tap(find.text("中华民国"));
      await tester.pumpAndSettle();
      expect(find.text("opened:中华民国"), findsOneWidget);
    });

    testWidgets("suffix mode in the bar shows headwords ending with it", (
      tester,
    ) async {
      // Same runAsync reasoning as the full-text test above: the
      // suggestion builder awaits a drift query.
      settings.searchMode = SearchMode.suffix;
      final controller = SearchController();
      addTearDown(controller.dispose);
      final router = buildRouter(controller);
      addTearDown(router.dispose);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              historyModelProvider.overrideWith((ref) => _TestHistoryModel()),
              dictManagerModelProvider.overrideWith(
                (ref) => DictManagerModel(),
              ),
              fullTextSearchServiceProvider.overrideWith(
                (ref) => suffixService,
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(SearchBar));
        await tester.pumpAndSettle();
        controller.text = "主义";
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
      });

      expect(find.text("社会主义"), findsOneWidget);
      expect(find.text("马克思主义"), findsOneWidget);
      // Contains 主义 but does not end with it.
      expect(find.text("主义者"), findsNothing);
    });
  });
}

import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/open_records.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/mobile_word_browser.dart";
import "package:ciyue/viewModels/home.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

class _FakeOpenRecordsRepository implements OpenRecordsRepository {
  @override
  Future<void> add(String word) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInAppWebViewPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    return _FakeInAppWebViewWidget(params);
  }
}

class _FakeInAppWebViewWidget extends PlatformInAppWebViewWidget {
  // ignore: use_super_parameters
  _FakeInAppWebViewWidget(PlatformInAppWebViewWidgetCreationParams params)
    : super.implementation(params);

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) {
    throw UnimplementedError();
  }

  @override
  void dispose() {}
}

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
    InAppWebViewPlatform.instance = _FakeInAppWebViewPlatform();
  });

  const dictIds = [10];

  setUp(() {
    for (final id in dictIds) {
      dictManager.dicts[id] = Mdict(path: "unused_$id")
        ..id = id
        ..title = "dict $id"
        ..port = 1;
    }
    settings.dictionarySwitchStyle = DictionarySwitchStyle.tag;
    settings.aiExplainWord = false;
  });

  tearDown(() {
    for (final id in dictIds) {
      dictManager.dicts.remove(id);
    }
  });

  Widget buildTestWidget({
    required HomeModel homeModel,
    String initialWord = "apple",
  }) {
    final router = GoRouter(
      initialLocation: "/word/$initialWord",
      routes: [
        GoRoute(
          path: "/word/:word",
          builder: (context, state) {
            final word = state.pathParameters["word"]!;
            return MobileWordBrowser(initialWord: word);
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        homeModelProvider.overrideWith((ref) => homeModel),
        validDictIdsProvider.overrideWith((ref, word) async => dictIds),
        dictionaryLookupProvider.overrideWith(
          (ref, word) async =>
              const DictionaryLookupResult(entriesByDictionary: {}),
        ),
        wordContentProvider.overrideWith(
          (ref, params) async => "<div>content</div>",
        ),
        openRecordsRepositoryProvider.overrideWithValue(
          _FakeOpenRecordsRepository(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets(
    "renders Chrome bottom bar with back, forward, new tab, tabs badge",
    (tester) async {
      final homeModel = HomeModel();
      await tester.pumpWidget(buildTestWidget(homeModel: homeModel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MobileWordBottomBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      // Initial state: canGoBack and canGoForward should be false
      final backButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
      );
      final forwardButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_forward_rounded),
      );
      expect(backButton.onPressed, isNull);
      expect(forwardButton.onPressed, isNull);

      // Tab count badge displays '1'
      expect(find.text("1"), findsOneWidget);
    },
  );

  testWidgets("navigating in current tab enables back and forward", (
    tester,
  ) async {
    final homeModel = HomeModel();
    await tester.pumpWidget(buildTestWidget(homeModel: homeModel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Navigate to second word
    homeModel.navigateInCurrentTab("banana");
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final backButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
    );
    expect(backButton.onPressed, isNotNull);

    // Tap back button
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(homeModel.selectedWord, "apple");

    // Forward button should now be enabled
    final forwardButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_forward_rounded),
    );
    expect(forwardButton.onPressed, isNotNull);

    // Tap forward button
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.arrow_forward_rounded),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(homeModel.selectedWord, "banana");
  });

  testWidgets("tapping tab switcher toggles Tab Overview and shows open tabs", (
    tester,
  ) async {
    final homeModel = HomeModel();
    homeModel.openWordInNewTab("apple");
    homeModel.openWordInNewTab("banana");

    await tester.pumpWidget(buildTestWidget(homeModel: homeModel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MobileTabOverview), findsNothing);

    // Tap tab badge to open overview
    homeModel.toggleTabOverview();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MobileTabOverview), findsOneWidget);
    expect(find.text("apple"), findsOneWidget);
    expect(find.text("banana"), findsOneWidget);

    // Tap first tab card to switch back to apple
    await tester.tap(find.text("apple"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MobileTabOverview), findsNothing);
    expect(homeModel.selectedWord, "apple");
  });

  testWidgets("tapping add button opens MobileNewTabPage and loads word", (
    tester,
  ) async {
    final homeModel = HomeModel();
    await tester.pumpWidget(buildTestWidget(homeModel: homeModel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MobileNewTabPage), findsNothing);

    // Tap '+' (New Tab) button in bottom bar
    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MobileNewTabPage), findsOneWidget);
    expect(homeModel.tabs.length, 2);

    // Tapping back button on the new tab closes it
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MobileNewTabPage), findsNothing);
    expect(homeModel.tabs.length, 1);
    expect(homeModel.selectedWord, "apple");
  });

  testWidgets(
    "submitting search on MobileNewTabPage transitions to WordDisplay without error",
    (tester) async {
      final homeModel = HomeModel();
      await tester.pumpWidget(buildTestWidget(homeModel: homeModel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open new tab
      homeModel.newTab();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MobileNewTabPage), findsOneWidget);

      // Enter text and submit
      await tester.enterText(find.byType(SearchBar), "cherry");
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MobileNewTabPage), findsNothing);
      expect(homeModel.selectedWord, "cherry");
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    "exiting MobileWordBrowser closes all tabs so next word lookup starts fresh",
    (tester) async {
      final homeModel = HomeModel();
      late BuildContext rootContext;
      final router = GoRouter(
        initialLocation: "/",
        routes: [
          GoRoute(
            path: "/",
            builder: (context, state) {
              rootContext = context;
              return const Scaffold(body: Text("Home"));
            },
          ),
          GoRoute(
            path: "/word/:word",
            builder: (context, state) {
              final word = state.pathParameters["word"]!;
              return MobileWordBrowser(initialWord: word);
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeModelProvider.overrideWith((ref) => homeModel),
            validDictIdsProvider.overrideWith((ref, word) async => dictIds),
            dictionaryLookupProvider.overrideWith(
              (ref, word) async =>
                  const DictionaryLookupResult(entriesByDictionary: {}),
            ),
            wordContentProvider.overrideWith(
              (ref, params) async => "<div>content</div>",
            ),
            openRecordsRepositoryProvider.overrideWithValue(
              _FakeOpenRecordsRepository(),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Push /word/apple from home
      rootContext.push("/word/apple");
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(homeModel.tabs, ["apple"]);

      // Tap back button in AppBar to exit back to home
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // After exiting, tabs are cleanly cleared
      expect(homeModel.tabs, isEmpty);
      expect(find.text("Home"), findsOneWidget);
    },
  );
}

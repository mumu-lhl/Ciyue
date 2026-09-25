import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/open_records.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/word_display.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart" as provider;
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

  const dictIds = [10, 20, 30];

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

  Widget buildTestWidget({String initialLocation = "/word/apple"}) {
    final testRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: "/word/:word",
          builder: (context, state) {
            final word = state.pathParameters["word"]!;
            final dictIdParam = state.uri.queryParameters["dictId"];
            final initialDictId = dictIdParam != null
                ? int.tryParse(dictIdParam)
                : null;
            return WordDisplay(word: word, initialDictId: initialDictId);
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        validDictIdsProvider.overrideWith((ref, word) async => dictIds),
        dictionaryLookupProvider.overrideWith(
          (ref, word) async =>
              const DictionaryLookupResult(entriesByDictionary: {}),
        ),
        wordContentProvider.overrideWith(
          (ref, params) async => "<div>content</div>",
        ),
      ],
      child: provider.MultiProvider(
        providers: [
          provider.Provider<OpenRecordsRepository>.value(
            value: _FakeOpenRecordsRepository(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: testRouter,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }

  testWidgets("WordDisplay opens initialDictId tab without AI", (tester) async {
    settings.aiExplainWord = false;

    await tester.pumpWidget(
      buildTestWidget(initialLocation: "/word/apple?dictId=20"),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final tabController = tester.widget<DefaultTabController>(
      find.byType(DefaultTabController),
    );
    expect(tabController.initialIndex, equals(1));
  });

  testWidgets("WordDisplay opens initialDictId tab with AI offset", (
    tester,
  ) async {
    settings.aiExplainWord = true;

    await tester.pumpWidget(
      buildTestWidget(initialLocation: "/word/apple?dictId=20"),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final tabController = tester.widget<DefaultTabController>(
      find.byType(DefaultTabController),
    );
    // AI is at index 0, dict 10 is at 1, dict 20 is at 2
    expect(tabController.initialIndex, equals(2));
  });

  testWidgets("WordDisplay falls back to 0 when initialDictId is not found", (
    tester,
  ) async {
    settings.aiExplainWord = false;

    await tester.pumpWidget(
      buildTestWidget(initialLocation: "/word/apple?dictId=999"),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final tabController = tester.widget<DefaultTabController>(
      find.byType(DefaultTabController),
    );
    expect(tabController.initialIndex, equals(0));
  });

  testWidgets("WordDisplay falls back to 0 when initialDictId is null", (
    tester,
  ) async {
    settings.aiExplainWord = false;

    await tester.pumpWidget(buildTestWidget(initialLocation: "/word/apple"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final tabController = tester.widget<DefaultTabController>(
      find.byType(DefaultTabController),
    );
    expect(tabController.initialIndex, equals(0));
  });

  testWidgets("pushing /word route with dictId selects target dict tab", (
    tester,
  ) async {
    settings.aiExplainWord = false;

    late BuildContext currentContext;
    final testRouter = GoRouter(
      initialLocation: "/word/apple",
      routes: [
        GoRoute(
          path: "/word/:word",
          builder: (context, state) {
            currentContext = context;
            final word = state.pathParameters["word"]!;
            final dictIdParam = state.uri.queryParameters["dictId"];
            final initialDictId = dictIdParam != null
                ? int.tryParse(dictIdParam)
                : null;
            return WordDisplay(
              key: ValueKey("word_${word}_$initialDictId"),
              word: word,
              initialDictId: initialDictId,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          validDictIdsProvider.overrideWith((ref, word) async => dictIds),
          dictionaryLookupProvider.overrideWith(
            (ref, word) async =>
                const DictionaryLookupResult(entriesByDictionary: {}),
          ),
          wordContentProvider.overrideWith(
            (ref, params) async => "<div>content</div>",
          ),
        ],
        child: provider.MultiProvider(
          providers: [
            provider.Provider<OpenRecordsRepository>.value(
              value: _FakeOpenRecordsRepository(),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // First word 'apple' without dictId has initialIndex 0
    var tabControllers = tester.widgetList<DefaultTabController>(
      find.byType(DefaultTabController),
    );
    expect(tabControllers.last.initialIndex, equals(0));

    // Push new word 'banana' with dictId=30 (index 2)
    currentContext.push("/word/banana?dictId=30");
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    tabControllers = tester.widgetList<DefaultTabController>(
      find.byType(DefaultTabController),
    );
    expect(tabControllers.last.initialIndex, equals(2));
  });
}

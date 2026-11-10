import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/open_records.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

class _FakeOpenRecordsRepository implements OpenRecordsRepository {
  final List<String> history = [];

  @override
  Future<void> add(String word) async {
    history.add(word);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  Finder findWord(String word) {
    return find.byWidgetPredicate((w) => w is Text && w.data == word);
  }

  Widget buildTestHost({
    required List<String> words,
    required int initialIndex,
    required _FakeOpenRecordsRepository openRecords,
  }) {
    final router = GoRouter(
      initialLocation: "/word/${words[initialIndex]}",
      routes: [
        GoRoute(
          path: "/word/:word",
          builder: (context, state) =>
              WordDisplayPager(words: words, initialIndex: initialIndex),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        validDictIdsProvider.overrideWith((ref, word) async => []),
        openRecordsRepositoryProvider.overrideWithValue(openRecords),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets(
    "WordDisplayPager displays initial index, shows progress, and supports navigation",
    (tester) async {
      final fakeRecords = _FakeOpenRecordsRepository();
      const words = ["apple", "banana", "cherry"];

      await tester.pumpWidget(
        buildTestHost(words: words, initialIndex: 1, openRecords: fakeRecords),
      );
      await tester.pumpAndSettle();

      expect(findWord("banana"), findsOneWidget);
      expect(find.text("2 / 3"), findsOneWidget);

      expect(fakeRecords.history.contains("banana"), isTrue);

      final prevFinder = find.widgetWithIcon(IconButton, Icons.chevron_left);
      final nextFinder = find.widgetWithIcon(IconButton, Icons.chevron_right);

      expect(prevFinder, findsOneWidget);
      expect(nextFinder, findsOneWidget);

      final prevBtn = tester.widget<IconButton>(prevFinder);
      final nextBtn = tester.widget<IconButton>(nextFinder);
      expect(prevBtn.onPressed, isNotNull);
      expect(nextBtn.onPressed, isNotNull);

      await tester.tap(prevFinder);
      await tester.pumpAndSettle();

      expect(findWord("apple"), findsOneWidget);
      expect(find.text("1 / 3"), findsOneWidget);
      expect(fakeRecords.history.contains("apple"), isTrue);

      final prevBtnAt0 = tester.widget<IconButton>(prevFinder);
      expect(prevBtnAt0.onPressed, isNull);

      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
      expect(findWord("banana"), findsOneWidget);

      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
      expect(findWord("cherry"), findsOneWidget);
      expect(find.text("3 / 3"), findsOneWidget);
      expect(fakeRecords.history.contains("cherry"), isTrue);

      final nextBtnAtEnd = tester.widget<IconButton>(nextFinder);
      expect(nextBtnAtEnd.onPressed, isNull);
    },
  );

  testWidgets("WordDisplayPager supports horizontal swiping", (tester) async {
    final fakeRecords = _FakeOpenRecordsRepository();
    const words = ["apple", "banana", "cherry"];

    await tester.pumpWidget(
      buildTestHost(words: words, initialIndex: 0, openRecords: fakeRecords),
    );
    await tester.pumpAndSettle();

    expect(findWord("apple"), findsOneWidget);
    expect(find.text("1 / 3"), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(findWord("banana"), findsOneWidget);
    expect(find.text("2 / 3"), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();

    expect(findWord("apple"), findsOneWidget);
    expect(find.text("1 / 3"), findsOneWidget);
  });

  testWidgets("WordDisplayPager supports arrow key navigation", (tester) async {
    final fakeRecords = _FakeOpenRecordsRepository();
    const words = ["apple", "banana", "cherry"];

    await tester.pumpWidget(
      buildTestHost(words: words, initialIndex: 0, openRecords: fakeRecords),
    );
    await tester.pumpAndSettle();

    expect(findWord("apple"), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(findWord("banana"), findsOneWidget);
    expect(find.text("2 / 3"), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(findWord("apple"), findsOneWidget);
    expect(find.text("1 / 3"), findsOneWidget);
  });

  testWidgets(
    "pager keeps each page's own word when the home tab has a selection",
    (tester) async {
      final fakeRecords = _FakeOpenRecordsRepository();
      const words = ["apple", "banana", "cherry"];

      await tester.pumpWidget(
        buildTestHost(words: words, initialIndex: 0, openRecords: fakeRecords),
      );
      await tester.pumpAndSettle();

      // A pushed entry page follows the home tab's selection; the pager must
      // not, otherwise every page would show this same word.
      final context = tester.element(find.byType(WordDisplayPager));
      ProviderScope.containerOf(context).read(homeModelProvider).selectedWord =
          "apple";
      await tester.pumpAndSettle();

      expect(findWord("apple"), findsOneWidget);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(findWord("banana"), findsOneWidget);
      expect(find.text("2 / 3"), findsOneWidget);
    },
  );
}

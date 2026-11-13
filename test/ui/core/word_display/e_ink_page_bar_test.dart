import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/entry_pager.dart";
import "package:ciyue/ui/core/word_display/paging_buttons.dart";
import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

class _FakePager implements EntryPager {
  final ValueNotifier<PageBounds> _bounds = ValueNotifier(PageBounds.unknown);
  final List<int> calls = [];

  @override
  ValueListenable<PageBounds> get bounds => _bounds;

  @override
  Future<bool> pageBy(int screens) async {
    calls.add(screens);
    return true;
  }

  void setBounds(PageBounds value) => _bounds.value = value;
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  late _FakePager pager;

  setUp(() {
    pager = _FakePager();
    registerEntryPager(
      "bar",
      dictId: () => 1,
      isCurrent: () => true,
      pager: pager,
    );
    setActiveEntryDict(1);
  });

  tearDown(() {
    unregisterEntryPager("bar");
    setActiveEntryDict(null);
  });

  testWidgets("the bar hides itself while no entry pager is on screen", (
    tester,
  ) async {
    setActiveEntryDict(null);
    await tester.pumpWidget(_app(const EInkPageBar()));
    await tester.pump();

    expect(find.byType(PagingButton), findsNothing);
  });

  testWidgets("the bar greys out the direction that cannot move", (
    tester,
  ) async {
    pager.setBounds(const PageBounds(atStart: true, atEnd: false));
    await tester.pumpWidget(_app(const EInkPageBar()));
    await tester.pump();

    final up = tester.widget<TextButton>(find.byKey(PagingButton.keyFor(-1)));
    final down = tester.widget<TextButton>(find.byKey(PagingButton.keyFor(1)));
    expect(up.onPressed, isNull);
    expect(down.onPressed, isNotNull);

    pager.setBounds(const PageBounds(atStart: false, atEnd: true));
    await tester.pump();

    final upAfter = tester.widget<TextButton>(
      find.byKey(PagingButton.keyFor(-1)),
    );
    final downAfter = tester.widget<TextButton>(
      find.byKey(PagingButton.keyFor(1)),
    );
    expect(upAfter.onPressed, isNotNull);
    expect(downAfter.onPressed, isNull);
  });

  testWidgets("tapping a button pages the entry by one screen", (tester) async {
    pager.setBounds(const PageBounds(atStart: false, atEnd: false));
    await tester.pumpWidget(_app(const EInkPageBar()));
    await tester.pump();

    await tester.tap(find.byKey(PagingButton.keyFor(1)));
    await tester.pump();
    await tester.tap(find.byKey(PagingButton.keyFor(-1)));
    await tester.pump();

    expect(pager.calls, [1, -1]);
  });

  group("buildEntryBottomBar", () {
    const existing = SizedBox(key: ValueKey("existing"));
    const searchBar = TextField();

    test("never stacks a second bar on a caller-supplied one", () {
      final bar = buildEntryBottomBar(
        eInkMode: true,
        existing: existing,
        searchBar: searchBar,
      );
      expect(bar, same(existing));
    });

    test("stacks the paging bar above the bottom search box", () {
      final bar = buildEntryBottomBar(
        eInkMode: true,
        existing: null,
        searchBar: searchBar,
      );
      expect(bar, isA<Column>());
      final children = (bar! as Column).children;
      expect(children.first, isA<EInkPageBar>());
      expect(children.last, isA<BottomAppBar>());
    });

    test("leaves the bottom bar alone when the mode is off", () {
      final bar = buildEntryBottomBar(
        eInkMode: false,
        existing: null,
        searchBar: searchBar,
      );
      expect(bar, isA<BottomAppBar>());
    });

    test("a page with no bottom bar keeps none", () {
      expect(
        buildEntryBottomBar(eInkMode: false, existing: null, searchBar: null),
        isNull,
      );
    });
  });
}

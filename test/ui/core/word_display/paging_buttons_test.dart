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
      "buttons",
      dictId: () => 1,
      isCurrent: () => true,
      pager: pager,
    );
    setActiveEntryDict(1);
  });

  tearDown(() {
    unregisterEntryPager("buttons");
    setActiveEntryDict(null);
  });

  testWidgets("both buttons stay disabled while no entry is on screen", (
    tester,
  ) async {
    setActiveEntryDict(null);
    await tester.pumpWidget(
      _app(
        const Row(
          children: [PagingButton(screens: -1), PagingButton(screens: 1)],
        ),
      ),
    );
    await tester.pump();

    for (final screens in [-1, 1]) {
      final button = tester.widget<IconButton>(
        find.byKey(PagingButton.keyFor(screens)),
      );
      expect(button.onPressed, isNull);
    }
  });

  testWidgets("a button greys out in the direction that cannot move", (
    tester,
  ) async {
    pager.setBounds(const PageBounds(atStart: true, atEnd: false));
    await tester.pumpWidget(
      _app(
        const Row(
          children: [PagingButton(screens: -1), PagingButton(screens: 1)],
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<IconButton>(find.byKey(PagingButton.keyFor(-1))).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.byKey(PagingButton.keyFor(1))).onPressed,
      isNotNull,
    );

    pager.setBounds(const PageBounds(atStart: false, atEnd: true));
    await tester.pump();

    expect(
      tester.widget<IconButton>(find.byKey(PagingButton.keyFor(-1))).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<IconButton>(find.byKey(PagingButton.keyFor(1))).onPressed,
      isNull,
    );
  });

  testWidgets("tapping a button pages the entry by one screen", (tester) async {
    pager.setBounds(const PageBounds(atStart: false, atEnd: false));
    await tester.pumpWidget(
      _app(
        const Row(
          children: [PagingButton(screens: -1), PagingButton(screens: 1)],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(PagingButton.keyFor(1)));
    await tester.pump();
    await tester.tap(find.byKey(PagingButton.keyFor(-1)));
    await tester.pump();

    expect(pager.calls, [1, -1]);
  });

  testWidgets("an explicit pager is paged instead of the entry", (
    tester,
  ) async {
    final history = _FakePager();
    history.setBounds(const PageBounds(atStart: false, atEnd: false));
    pager.setBounds(const PageBounds(atStart: false, atEnd: false));

    await tester.pumpWidget(_app(PagingButton(screens: 1, pager: history)));
    await tester.pump();

    await tester.tap(find.byKey(PagingButton.keyFor(1)));
    await tester.pump();

    expect(history.calls, [1]);
    expect(pager.calls, isEmpty);
  });
}

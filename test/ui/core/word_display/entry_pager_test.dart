import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/word_display/entry_pager.dart";
import "package:flutter/foundation.dart";
import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  tearDown(() {
    unregisterEntryPager("a");
    unregisterEntryPager("b");
    setExpansionEntryPager(null);
    setActiveEntryDict(null);
    settings.eInkMode = false;
  });

  group("registry", () {
    test("routes to the pager of the dictionary on screen", () async {
      final first = _FakePager();
      final second = _FakePager();
      registerEntryPager(
        "a",
        dictId: () => 1,
        isCurrent: () => true,
        pager: first,
      );
      registerEntryPager(
        "b",
        dictId: () => 2,
        isCurrent: () => true,
        pager: second,
      );

      setActiveEntryDict(2);
      expect(await pageActiveEntry(1), isTrue);
      expect(second.calls, [1]);
      expect(first.calls, isEmpty);
    });

    test("falls back to the expansion pager when no tab matches", () async {
      final expansion = _FakePager();
      setExpansionEntryPager(expansion);
      setActiveEntryDict(7);

      expect(await pageActiveEntry(-1), isTrue);
      expect(expansion.calls, [-1]);
    });

    test("does nothing when no entry is on screen", () async {
      setActiveEntryDict(null);
      expect(await pageActiveEntry(1), isFalse);
    });

    test("publishes the pager the buttons must talk to", () {
      final pager = _FakePager();
      registerEntryPager(
        "a",
        dictId: () => 3,
        isCurrent: () => true,
        pager: pager,
      );
      setActiveEntryDict(3);

      expect(activeEntryPager.value, same(pager));

      unregisterEntryPager("a");
      expect(activeEntryPager.value, isNull);
    });
  });

  group("ScrollControllerEntryPager", () {
    testWidgets("pages by 90% of the viewport and clamps at the end", (
      tester,
    ) async {
      // The e-ink mode is what makes the pager jump instead of animating, so
      // the future completes without pumping frames.
      settings.eInkMode = true;

      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            controller: controller,
            child: const SizedBox(width: 100, height: 3000),
          ),
        ),
      );

      final pager = ScrollControllerEntryPager(controller);
      addTearDown(pager.dispose);

      final viewport = controller.position.viewportDimension;
      expect(pager.bounds.value.atStart, isTrue);
      expect(pager.bounds.value.atEnd, isFalse);

      expect(await pager.pageBy(1), isTrue);
      expect(controller.position.pixels, closeTo(viewport * 0.9, 0.5));
      expect(pager.bounds.value.atStart, isFalse);

      while (await pager.pageBy(1)) {
        // Page down until the pager says it cannot move any further.
      }
      expect(pager.bounds.value.atEnd, isTrue);
      expect(await pager.pageBy(1), isFalse);

      expect(await pager.pageBy(-1), isTrue);
    });

    testWidgets("a page shorter than the viewport never moves", (tester) async {
      settings.eInkMode = true;

      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            controller: controller,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );

      final pager = ScrollControllerEntryPager(controller);
      addTearDown(pager.dispose);

      expect(pager.bounds.value.atStart, isTrue);
      expect(pager.bounds.value.atEnd, isTrue);
      expect(await pager.pageBy(1), isFalse);
    });
  });
}

import "package:ciyue/services/floating_window_preferences.dart";
import "package:ciyue/ui/core/floating_window_shell.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  const panelChildKey = ValueKey("floating_panel_child");

  Future<Size> measurePanel(WidgetTester tester, Size window) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: FloatingWindowShell(
          child: const SizedBox.expand(key: panelChildKey),
        ),
      ),
    );
    return tester.getSize(find.byKey(panelChildKey));
  }

  testWidgets("landscape windows get a wider, lower panel", (tester) async {
    final size = await measurePanel(tester, const Size(1280, 800));

    expect(size.width, 900.0);
    expect(size.height, 520.0);
    // Previous geometry: 540 x (800 * 0.7) = 540 x 560.
    expect(size.width, greaterThan(540.0));
    expect(size.height, lessThan(560.0));
  });

  testWidgets("landscape phone does not overflow the window", (tester) async {
    const window = Size(844, 390);
    final size = await measurePanel(tester, window);

    expect(size.width, closeTo(675.2, 0.001));
    expect(size.height, closeTo(253.5, 0.001));
    expect(size.width, lessThanOrEqualTo(window.width));
    expect(size.height, lessThanOrEqualTo(window.height));
  });

  testWidgets("very short landscape window keeps the panel inside", (
    tester,
  ) async {
    const window = Size(800, 360);
    final size = await measurePanel(tester, window);

    // The old 420 minimum was taller than this window.
    expect(size.height, lessThanOrEqualTo(window.height));
  });

  testWidgets("portrait tablet keeps the original card", (tester) async {
    final size = await measurePanel(tester, const Size(800, 1280));

    expect(size.width, 540.0);
    expect(size.height, 720.0);
  });

  testWidgets("portrait phone keeps the original card", (tester) async {
    final size = await measurePanel(tester, const Size(400, 800));

    expect(size.width, closeTo(340.0, 0.001));
    expect(size.height, closeTo(440.0, 0.001));
  });

  testWidgets("small portrait free-form window keeps the original card", (
    tester,
  ) async {
    final size = await measurePanel(tester, const Size(286, 575));

    expect(size.width, closeTo(243.1, 0.001));
    expect(size.height, closeTo(316.25, 0.001));
  });

  Future<void> pumpModeView(WidgetTester tester, Size window) async {
    const childKey = ValueKey("mode_view_child");
    floatingWindowMode.value = FloatingWindowMode.halfScreen;
    addTearDown(() {
      floatingWindowMode.value = FloatingWindowMode.transparent;
    });

    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: floatingWindowView(child: const SizedBox.expand(key: childKey)),
      ),
    );
  }

  testWidgets("half-screen mode fills the whole window", (tester) async {
    const window = Size(1024, 600);
    await pumpModeView(tester, window);

    expect(
      tester.getSize(find.byKey(const ValueKey("mode_view_child"))),
      window,
    );
  });

  testWidgets("switching back to transparent restores the centred card", (
    tester,
  ) async {
    await pumpModeView(tester, const Size(1024, 600));

    floatingWindowMode.value = FloatingWindowMode.transparent;
    await tester.pump();

    final size = tester.getSize(find.byKey(const ValueKey("mode_view_child")));
    expect(size.width, closeTo(819.2, 0.001));
    expect(size.height, closeTo(390.0, 0.001));
  });
}

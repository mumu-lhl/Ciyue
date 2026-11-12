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

    // 0.85 of the width and 0.55 of the height: no pixel cap any more.
    expect(size.width, closeTo(1088.0, 0.001));
    expect(size.height, closeTo(440.0, 0.001));
    expect(size.height, lessThan(size.width));
  });

  testWidgets("landscape phone does not overflow the window", (tester) async {
    const window = Size(844, 390);
    final size = await measurePanel(tester, window);

    expect(size.width, closeTo(717.4, 0.001));
    // 0.55 of the height would be 214.5, below the readable minimum.
    expect(size.height, minPanelHeight);
    expect(size.width, lessThanOrEqualTo(window.width));
    expect(size.height, lessThanOrEqualTo(window.height));
  });

  testWidgets("very short landscape window keeps the panel inside", (
    tester,
  ) async {
    const window = Size(800, 360);
    final size = await measurePanel(tester, window);

    expect(size.height, minPanelHeight);
    expect(size.height, lessThanOrEqualTo(window.height));
  });

  testWidgets("portrait tablet uses the same fraction", (tester) async {
    final size = await measurePanel(tester, const Size(800, 1280));

    expect(size.width, closeTo(680.0, 0.001));
    expect(size.height, closeTo(704.0, 0.001));
  });

  testWidgets("portrait phone keeps the original card", (tester) async {
    final size = await measurePanel(tester, const Size(400, 800));

    expect(size.width, closeTo(340.0, 0.001));
    expect(size.height, closeTo(440.0, 0.001));
  });

  testWidgets("a tiny free-form window still gets a readable card", (
    tester,
  ) async {
    final size = await measurePanel(tester, const Size(286, 575));

    // 0.85 of the width would be 243.1, below the readable minimum.
    expect(size.width, minPanelWidth);
    expect(size.height, closeTo(316.25, 0.001));
  });

  test("a tiny fraction is raised to the readable minimum", () {
    const constraints = BoxConstraints(maxWidth: 400, maxHeight: 400);

    final size = floatingWindowPanelSize(
      constraints,
      fraction: const FloatingWindowPanelFraction(width: 0.5, height: 0.4),
    );

    expect(size.width, minPanelWidth);
    expect(size.height, minPanelHeight);
  });

  test("a window smaller than the minimum is never overflowed", () {
    const constraints = BoxConstraints(maxWidth: 200, maxHeight: 180);

    final size = floatingWindowPanelSize(
      constraints,
      fraction: const FloatingWindowPanelFraction(width: 0.5, height: 0.5),
    );

    expect(size.width, 200.0);
    expect(size.height, 180.0);
  });

  test("panel size follows the configured fraction", () {
    const constraints = BoxConstraints(maxWidth: 800, maxHeight: 600);

    final size = floatingWindowPanelSize(
      constraints,
      fraction: const FloatingWindowPanelFraction(width: 0.5, height: 0.5),
    );

    expect(size.width, 400.0);
    expect(size.height, 300.0);
  });

  test("a full fraction covers the whole window", () {
    const constraints = BoxConstraints(maxWidth: 2000, maxHeight: 2000);

    final size = floatingWindowPanelSize(
      constraints,
      fraction: const FloatingWindowPanelFraction(width: 1.0, height: 1.0),
    );

    expect(size.width, 2000.0);
    expect(size.height, 2000.0);
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
    expect(size.width, closeTo(870.4, 0.001));
    expect(size.height, closeTo(330.0, 0.001));
  });
}

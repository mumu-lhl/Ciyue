import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

Widget buildTestFloatingWindowWrapper({required Widget child}) {
  return Stack(
    alignment: Alignment.topLeft,
    fit: StackFit.expand,
    children: [
      Align(
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            final width = isWide ? 540.0 : constraints.maxWidth * 0.85;
            final height = isWide
                ? (constraints.maxHeight * 0.7).clamp(420.0, 720.0)
                : constraints.maxHeight * 0.55;
            return SizedBox(
              key: const ValueKey("floating_panel_box"),
              width: width,
              height: height,
              child: child,
            );
          },
        ),
      ),
    ],
  );
}

void main() {
  testWidgets("floating window sizes appropriately on wide screens", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: buildTestFloatingWindowWrapper(child: const SizedBox.expand()),
      ),
    );

    final box = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey("floating_panel_box")),
    );
    expect(box.size.width, equals(540.0));
    expect(box.size.height, equals(720.0)); // 1080 * 0.7 = 756 clamped to 720
  });

  testWidgets("floating window sizes appropriately on mobile screens", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: buildTestFloatingWindowWrapper(child: const SizedBox.expand()),
      ),
    );

    final box = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey("floating_panel_box")),
    );
    expect(box.size.width, closeTo(340.0, 0.001)); // 400 * 0.85
    expect(box.size.height, closeTo(440.0, 0.001)); // 800 * 0.55
  });
}

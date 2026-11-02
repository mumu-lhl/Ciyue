import "package:ciyue/ui/pages/settings/appearance/trailing_segmented_button.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    required double availableWidth,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListTile(
            title: const Text("title"),
            trailing: TrailingSegmentedButton<int>(
              availableWidth: availableWidth,
              segments: const [
                ButtonSegment(
                  value: 1,
                  label: Text("Light"),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(value: 2, label: Text("Dark")),
              ],
              selected: const {1},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets("shows the labels next to their icons when they fit", (
    tester,
  ) async {
    await pumpButton(tester, availableWidth: 600);

    expect(find.text("Light"), findsOneWidget);
    expect(find.byIcon(Icons.light_mode), findsOneWidget);
  });

  testWidgets("drops the icons when only the labels fit", (tester) async {
    await pumpButton(tester, availableWidth: 300);

    expect(find.text("Light"), findsOneWidget);
    expect(find.byIcon(Icons.light_mode), findsNothing);
  });

  testWidgets("keeps only the icons when nothing else fits", (tester) async {
    await pumpButton(tester, availableWidth: 150);

    expect(find.text("Light"), findsNothing);
    expect(find.byIcon(Icons.light_mode), findsOneWidget);
  });

  testWidgets("keeps the labels on one line", (tester) async {
    await pumpButton(tester, availableWidth: 600);

    // A label that does not fit is cut off with an ellipsis instead of
    // breaking into one character per line.
    final label = tester.widget<Text>(find.text("Light"));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
  });
}

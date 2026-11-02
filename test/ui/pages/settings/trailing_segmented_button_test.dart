import "package:ciyue/ui/pages/settings/appearance/trailing_segmented_button.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  testWidgets("stacks the icon above a wrapping label", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListTile(
            title: const Text("title"),
            trailing: TrailingSegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 1,
                  label: Text("a very long label"),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(value: 2, label: Text("another one")),
              ],
              selected: const {1},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    // The button must not grow past its cap, or it takes the space the
    // title needs and squeezes it into one character per line.
    final button = tester.getSize(find.byType(TrailingSegmentedButton<int>));
    expect(button.width, lessThanOrEqualTo(200));

    // The label wraps rather than being cut off.
    final label = tester.widget<Text>(find.text("a very long label"));
    expect(label.softWrap, isTrue);
    expect(label.maxLines, isNull);
    expect(label.overflow, isNull);

    // A word that does not fit has to end up on more than one line.
    expect(
      tester.getSize(find.text("a very long label")).height,
      greaterThan(20),
    );

    // The icon sits above the text.
    final column = tester.widget<Column>(
      find
          .descendant(
            of: find.byType(TrailingSegmentedButton<int>),
            matching: find.byType(Column),
          )
          .first,
    );
    expect(column.children.first, isA<Icon>());
  });
}

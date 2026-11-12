import "package:ciyue/ui/core/app_dropdown.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  Future<void> pumpDropdown(
    WidgetTester tester, {
    String? value,
    ValueChanged<String?>? onChanged,
    bool dense = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppDropdown<String>(
              value: value,
              label: "Choice",
              dense: dense,
              items: const [
                DropdownMenuItem(value: "a", child: Text("Alpha")),
                DropdownMenuItem(value: "b", child: Text("Beta")),
                DropdownMenuItem(value: "c", child: Text("Gamma")),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("opens the menu and marks the selected item", (tester) async {
    await pumpDropdown(tester, value: "b", onChanged: (_) {});

    // The button shows the selected value before opening.
    expect(find.text("Beta"), findsOneWidget);

    await tester.tap(find.byType(AppDropdown<String>));
    await tester.pumpAndSettle();

    // All items are visible; the selected row carries the check.
    expect(find.text("Alpha"), findsOneWidget);
    expect(find.text("Gamma"), findsOneWidget);
    expect(find.text("Beta"), findsNWidgets(2));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets("tapping an item reports it and closes the menu", (tester) async {
    String? selected;
    await pumpDropdown(
      tester,
      value: "b",
      onChanged: (value) => selected = value,
    );

    await tester.tap(find.byType(AppDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Gamma"));
    await tester.pumpAndSettle();

    expect(selected, "c");
    expect(find.text("Alpha"), findsNothing);
  });

  testWidgets("tapping the null-valued item reports null", (tester) async {
    String? selected = "unset";
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppDropdown<String?>(
              value: "b",
              label: "Choice",
              items: const [
                DropdownMenuItem(value: null, child: Text("Default")),
                DropdownMenuItem(value: "b", child: Text("Beta")),
              ],
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppDropdown<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Default"));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });

  testWidgets("disabled dropdown does not open a menu", (tester) async {
    await pumpDropdown(tester, value: "b", onChanged: null);

    await tester.tap(find.byType(AppDropdown<String>));
    await tester.pumpAndSettle();

    expect(find.text("Alpha"), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets("dense pill shows the selected value", (tester) async {
    await pumpDropdown(tester, value: "a", onChanged: (_) {}, dense: true);

    expect(find.text("Alpha"), findsOneWidget);
    await tester.tap(find.byType(AppDropdown<String>));
    await tester.pumpAndSettle();
    expect(find.text("Gamma"), findsOneWidget);
  });
}

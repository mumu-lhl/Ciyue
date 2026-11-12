import "package:ciyue/ui/core/app_dropdown.dart";
import "package:ciyue/ui/core/settings_group.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

// Repro: dense AppDropdown inside a ListTile trailing in a SettingsGroupCard,
// exactly as on the Update settings page. In the real Linux window the pill
// does not open its menu.
void main() {
  testWidgets("dense pill in SettingsGroupCard ListTile opens its menu", (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: ListView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                children: [
                  SettingsGroupCard(
                    children: [
                      ListTile(
                        title: const Text("Update channel"),
                        subtitle: const Text("Stable"),
                        trailing: AppDropdown<String>(
                          value: "stable",
                          dense: true,
                          items: const [
                            DropdownMenuItem(
                              value: "stable",
                              child: Text("Stable"),
                            ),
                            DropdownMenuItem(
                              value: "preview",
                              child: Text("Preview"),
                            ),
                            DropdownMenuItem(
                              value: "nightly",
                              child: Text("Nightly"),
                            ),
                          ],
                          onChanged: (value) => selected = value,
                        ),
                        leading: const Icon(Icons.settings_suggest_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The pill must have a real size (a zero-size pill cannot be tapped).
    final size = tester.getSize(find.byType(AppDropdown<String>));
    expect(size.width, greaterThan(100));
    expect(size.height, greaterThan(30));

    await tester.tap(find.byType(AppDropdown<String>));
    await tester.pumpAndSettle();

    expect(find.text("Preview"), findsOneWidget);
    await tester.tap(find.text("Nightly"));
    await tester.pumpAndSettle();
    expect(selected, "nightly");
  });
}

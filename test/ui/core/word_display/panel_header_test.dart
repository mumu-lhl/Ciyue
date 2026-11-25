import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/word_display/panel_header.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  Future<void> pumpHeader(WidgetTester tester, PanelHeaderStyle style) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpansionPanelHeader(title: "t-dict.tsv", style: style),
        ),
      ),
    );
  }

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(ExpansionPanelHeader))).colorScheme;

  testWidgets("plain keeps the default title styling", (tester) async {
    await pumpHeader(tester, PanelHeaderStyle.plain);

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    final title = tester.widget<Text>(find.text("t-dict.tsv"));
    expect(tile.tileColor, isNull);
    expect(title.style?.color, isNull);
  });

  testWidgets("primary text colours only the title", (tester) async {
    await pumpHeader(tester, PanelHeaderStyle.primaryText);

    final scheme = schemeOf(tester);
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    final title = tester.widget<Text>(find.text("t-dict.tsv"));
    expect(tile.tileColor, isNull);
    expect(title.style?.color, scheme.primary);
  });

  testWidgets("tinted background uses the secondary container", (tester) async {
    await pumpHeader(tester, PanelHeaderStyle.tintedBackground);

    final scheme = schemeOf(tester);
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    final title = tester.widget<Text>(find.text("t-dict.tsv"));
    expect(tile.tileColor, scheme.secondaryContainer);
    expect(title.style?.color, scheme.onSecondaryContainer);
  });
}

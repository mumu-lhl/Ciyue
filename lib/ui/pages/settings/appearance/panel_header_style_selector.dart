import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/appearance/trailing_segmented_button.dart";
import "package:material_ui/material_ui.dart";

/// Picks how the dictionary name in an expansion panel is drawn.
class PanelHeaderStyleSelector extends StatefulWidget {
  const PanelHeaderStyleSelector({super.key});

  @override
  State<PanelHeaderStyleSelector> createState() =>
      _PanelHeaderStyleSelectorState();
}

class _PanelHeaderStyleSelectorState extends State<PanelHeaderStyleSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) => ListTile(
        leading: const Icon(Icons.title),
        title: Text(locale.panelHeaderStyle),
        trailing: TrailingSegmentedButton<PanelHeaderStyle>(
          availableWidth: constraints.maxWidth,
          segments: [
            ButtonSegment(
              value: PanelHeaderStyle.plain,
              icon: const Icon(Icons.text_fields),
              label: Text(locale.panelHeaderStylePlain),
            ),
            ButtonSegment(
              value: PanelHeaderStyle.primaryText,
              icon: const Icon(Icons.format_color_text),
              label: Text(locale.panelHeaderStylePrimaryText),
            ),
            ButtonSegment(
              value: PanelHeaderStyle.primaryBackground,
              icon: const Icon(Icons.format_color_fill),
              label: Text(locale.panelHeaderStylePrimaryBackground),
            ),
          ],
          selected: {settings.panelHeaderStyle},
          onSelectionChanged: (selected) async {
            if (selected.first != settings.panelHeaderStyle) {
              await settings.setPanelHeaderStyle(selected.first);
              setState(() {});
            }
          },
          showSelectedIcon: false,
        ),
      ),
    );
  }
}

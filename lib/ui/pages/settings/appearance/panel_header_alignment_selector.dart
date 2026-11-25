import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/appearance/trailing_segmented_button.dart";
import "package:material_ui/material_ui.dart";

/// Picks which side the dictionary name in an expansion panel sits on.
class PanelHeaderAlignmentSelector extends StatefulWidget {
  const PanelHeaderAlignmentSelector({super.key});

  @override
  State<PanelHeaderAlignmentSelector> createState() =>
      _PanelHeaderAlignmentSelectorState();
}

class _PanelHeaderAlignmentSelectorState
    extends State<PanelHeaderAlignmentSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) => ListTile(
        leading: const Icon(Icons.format_align_left),
        title: Text(locale.panelHeaderAlignment),
        trailing: TrailingSegmentedButton<PanelHeaderAlignment>(
          availableWidth: constraints.maxWidth,
          segments: [
            ButtonSegment(
              value: PanelHeaderAlignment.left,
              icon: const Icon(Icons.format_align_left),
              label: Text(locale.panelHeaderAlignmentLeft),
            ),
            ButtonSegment(
              value: PanelHeaderAlignment.right,
              icon: const Icon(Icons.format_align_right),
              label: Text(locale.panelHeaderAlignmentRight),
            ),
          ],
          selected: {settings.panelHeaderAlignment},
          onSelectionChanged: (selected) async {
            if (selected.first != settings.panelHeaderAlignment) {
              await settings.setPanelHeaderAlignment(selected.first);
              setState(() {});
            }
          },
          showSelectedIcon: false,
        ),
      ),
    );
  }
}

import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/appearance/trailing_segmented_button.dart";
import "package:material_ui/material_ui.dart";

/// Picks where the bookmark, pronunciation and paging buttons sit on a
/// phone-sized entry page. The options are whole layouts rather than per
/// button switches: a narrow bottom bar cannot hold every action at once.
class MobileToolbarPresetSelector extends StatefulWidget {
  const MobileToolbarPresetSelector({super.key});

  @override
  State<MobileToolbarPresetSelector> createState() =>
      _MobileToolbarPresetSelectorState();
}

class _MobileToolbarPresetSelectorState
    extends State<MobileToolbarPresetSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) => ListTile(
        leading: const Icon(Icons.view_quilt_outlined),
        title: Text(locale.mobileToolbarPreset),
        trailing: TrailingSegmentedButton<MobileToolbarPreset>(
          availableWidth: constraints.maxWidth,
          segments: [
            ButtonSegment(
              value: MobileToolbarPreset.floating,
              icon: const Icon(Icons.layers_outlined),
              label: Text(locale.mobileToolbarPresetFloating),
            ),
            ButtonSegment(
              value: MobileToolbarPreset.bottomSingle,
              icon: const Icon(Icons.view_stream_outlined),
              label: Text(locale.mobileToolbarPresetBottomSingle),
            ),
            ButtonSegment(
              value: MobileToolbarPreset.bottomDouble,
              icon: const Icon(Icons.view_agenda_outlined),
              label: Text(locale.mobileToolbarPresetBottomDouble),
            ),
            ButtonSegment(
              value: MobileToolbarPreset.eInkPaging,
              icon: const Icon(Icons.import_contacts_outlined),
              label: Text(locale.mobileToolbarPresetEInkPaging),
            ),
          ],
          selected: {settings.mobileToolbarPreset},
          onSelectionChanged: (selected) async {
            if (selected.first != settings.mobileToolbarPreset) {
              await settings.setMobileToolbarPreset(selected.first);
              setState(() {});
            }
          },
          showSelectedIcon: false,
        ),
      ),
    );
  }
}

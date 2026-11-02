import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/appearance/trailing_segmented_button.dart";
import "package:material_ui/material_ui.dart";

class DictionarySwitchStyleSelector extends StatefulWidget {
  const DictionarySwitchStyleSelector({super.key});

  @override
  State<DictionarySwitchStyleSelector> createState() =>
      _DictionarySwitchStyleSelectorState();
}

class _DictionarySwitchStyleSelectorState
    extends State<DictionarySwitchStyleSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) => ListTile(
        leading: const Icon(Icons.style),
        title: Text(locale.dictionarySwitchStyle),
        trailing: TrailingSegmentedButton<DictionarySwitchStyle>(
          availableWidth: constraints.maxWidth,
          segments: [
            ButtonSegment(
              value: DictionarySwitchStyle.expansion,
              label: Text(locale.expansion),
            ),
            ButtonSegment(
              value: DictionarySwitchStyle.tag,
              label: Text(locale.tab),
            ),
          ],
          selected: {settings.dictionarySwitchStyle},
          onSelectionChanged: (selected) async {
            if (selected.first != settings.dictionarySwitchStyle) {
              await settings.setDictionarySwitchStyle(selected.first);
              setState(() {});
            }
          },
          showSelectedIcon: false,
        ),
      ),
    );
  }
}

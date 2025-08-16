import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";

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

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final selected = await showMenu<DictionarySwitchStyle>(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.dictionarySwitchStyle,
          items: [
            PopupMenuItem(
              value: DictionarySwitchStyle.expansion,
              child: Text(locale.expansion),
            ),
            PopupMenuItem(
              value: DictionarySwitchStyle.tag,
              child: Text(locale.tab),
            ),
          ],
        );

        if (selected != null && selected != settings.dictionarySwitchStyle) {
          await settings.setDictionarySwitchStyle(selected);
          setState(() {});
        }
      },
      child: ListTile(
        leading: const Icon(Icons.style),
        title: Text(locale.dictionarySwitchStyle),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}

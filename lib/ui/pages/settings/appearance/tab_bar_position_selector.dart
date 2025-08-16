import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";

class TabBarPositionSelector extends StatefulWidget {
  const TabBarPositionSelector({super.key});

  @override
  State<TabBarPositionSelector> createState() => _TabBarPositionSelectorState();
}

class _TabBarPositionSelectorState extends State<TabBarPositionSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final selected = await showMenu<TabBarPosition>(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.tabBarPosition,
          items: [
            PopupMenuItem(
              value: TabBarPosition.top,
              child: Text(locale.top),
            ),
            PopupMenuItem(
              value: TabBarPosition.bottom,
              child: Text(locale.bottom),
            ),
          ],
        );

        if (selected != null && selected != settings.tabBarPosition) {
          await settings.setTabBarPosition(selected);
          setState(() {});
        }
      },
      child: ListTile(
        leading: const Icon(Icons.tab),
        title: Text(locale.tabBarPosition),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}

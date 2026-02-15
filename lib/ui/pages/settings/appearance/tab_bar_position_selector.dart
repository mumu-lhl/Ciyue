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

    return ListTile(
      leading: const Icon(Icons.tab),
      title: Text(locale.tabBarPosition),
      trailing: SegmentedButton<TabBarPosition>(
        segments: [
          ButtonSegment(
            value: TabBarPosition.top,
            label: Text(locale.top),
          ),
          ButtonSegment(
            value: TabBarPosition.bottom,
            label: Text(locale.bottom),
          ),
        ],
        selected: {settings.tabBarPosition},
        onSelectionChanged: (selected) async {
          if (selected.first != settings.tabBarPosition) {
            await settings.setTabBarPosition(selected.first);
            setState(() {});
          }
        },
        showSelectedIcon: false,
      ),
    );
  }
}

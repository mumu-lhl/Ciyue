import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class DrawerIconSwitch extends StatefulWidget {
  const DrawerIconSwitch({super.key});

  @override
  State<DrawerIconSwitch> createState() => _DrawerIconSwitchState();
}

class _DrawerIconSwitchState extends State<DrawerIconSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.sidebarIcon),
      value: settings.showSidebarIcon,
      onChanged: (value) async {
        await prefs.setBool("showSidebarIcon", value);
        if (context.mounted) context.read<HomeModel>().update();
        setState(() {
          settings.showSidebarIcon = value;
        });
      },
      secondary: const Icon(Icons.menu),
    );
  }
}

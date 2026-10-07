import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class DrawerIconSwitch extends ConsumerStatefulWidget {
  const DrawerIconSwitch({super.key});

  @override
  ConsumerState<DrawerIconSwitch> createState() => _DrawerIconSwitchState();
}

class _DrawerIconSwitchState extends ConsumerState<DrawerIconSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.sidebarIcon),
      value: settings.showSidebarIcon,
      onChanged: (value) async {
        await prefs.setBool("showSidebarIcon", value);
        ref.read(homeModelProvider).update();
        setState(() {
          settings.showSidebarIcon = value;
        });
      },
      secondary: const Icon(Icons.menu),
    );
  }
}

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class MoreOptionsButtonSwitch extends StatefulWidget {
  const MoreOptionsButtonSwitch({super.key});

  @override
  State<MoreOptionsButtonSwitch> createState() =>
      _MoreOptionsButtonSwitchState();
}

class _MoreOptionsButtonSwitchState extends State<MoreOptionsButtonSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.moreOptionsButton),
      value: settings.showMoreOptionsButton,
      onChanged: (value) async {
        await prefs.setBool("showMoreOptionsButton", value);
        if (context.mounted) context.read<HomeModel>().update();
        setState(() {
          settings.showMoreOptionsButton = value;
        });
      },
      secondary: const Icon(Icons.more_vert),
    );
  }
}

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";

class SearchbarInWordDisplaySwitch extends StatefulWidget {
  const SearchbarInWordDisplaySwitch({super.key});

  @override
  State<SearchbarInWordDisplaySwitch> createState() =>
      _SearchbarInWordDisplaySwitchState();
}

class _SearchbarInWordDisplaySwitchState
    extends State<SearchbarInWordDisplaySwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.showSearchBarInWordDisplayPage),
      value: settings.showSearchBarInWordDisplay,
      onChanged: (value) async {
        await prefs.setBool("showSearchBarInWordDisplay", value);
        setState(() {
          settings.showSearchBarInWordDisplay = value;
        });
      },
      secondary: const Icon(Icons.search),
    );
  }
}

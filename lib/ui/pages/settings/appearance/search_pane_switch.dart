import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class SearchPaneSwitch extends ConsumerStatefulWidget {
  const SearchPaneSwitch({super.key});

  @override
  ConsumerState<SearchPaneSwitch> createState() => _SearchPaneSwitchState();
}

class _SearchPaneSwitchState extends ConsumerState<SearchPaneSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.showSearchPane),
      value: settings.showSearchPane,
      onChanged: (value) async {
        // The setter writes the pref, updates the settings field and
        // notifies listeners, so the home split view rebuilds with it.
        await settings.setShowSearchPane(value);
        setState(() {});
      },
      secondary: const Icon(Icons.vertical_split),
    );
  }
}

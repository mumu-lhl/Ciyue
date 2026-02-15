import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class SearchbarLocationSelector extends StatefulWidget {
  const SearchbarLocationSelector({super.key});

  @override
  State<SearchbarLocationSelector> createState() =>
      _SearchbarLocationSelectorState();
}

class _SearchbarLocationSelectorState extends State<SearchbarLocationSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return ListTile(
      leading: const Icon(Icons.search),
      title: Text(locale.searchBarLocation),
      trailing: SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: true, label: Text(locale.top)),
          ButtonSegment(value: false, label: Text(locale.bottom)),
        ],
        selected: {settings.searchBarInAppBar},
        onSelectionChanged: (selected) async {
          final newValue = selected.first;
          if (newValue != settings.searchBarInAppBar) {
            settings.searchBarInAppBar = newValue;
            await prefs.setBool("searchBarInAppBar", newValue);
            if (context.mounted) context.read<HomeModel>().update();
            setState(() {});
          }
        },
        showSelectedIcon: false,
      ),
    );
  }
}

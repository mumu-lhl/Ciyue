import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/appearance/trailing_segmented_button.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class SearchbarLocationSelector extends ConsumerStatefulWidget {
  const SearchbarLocationSelector({super.key});

  @override
  ConsumerState<SearchbarLocationSelector> createState() =>
      _SearchbarLocationSelectorState();
}

class _SearchbarLocationSelectorState
    extends ConsumerState<SearchbarLocationSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) => ListTile(
        leading: const Icon(Icons.search),
        title: Text(locale.searchBarLocation),
        trailing: TrailingSegmentedButton<bool>(
          availableWidth: constraints.maxWidth,
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
              ref.read(homeModelProvider).update();
              setState(() {});
            }
          },
          showSelectedIcon: false,
        ),
      ),
    );
  }
}

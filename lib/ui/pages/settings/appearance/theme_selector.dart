import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";

class ThemeSelector extends StatefulWidget {
  const ThemeSelector({super.key});

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<ThemeSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return ListTile(
      leading: const Icon(Icons.light_mode),
      title: Text(locale.theme),
      trailing: SegmentedButton<ThemeMode>(
        segments: [
          ButtonSegment(
            value: ThemeMode.light,
            label: Text(locale.light),
            icon: const Icon(Icons.light_mode),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text(locale.dark),
            icon: const Icon(Icons.dark_mode),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            label: Text(locale.system),
            icon: const Icon(Icons.brightness_auto),
          ),
        ],
        selected: {settings.themeMode},
        onSelectionChanged: (selected) async {
          final themeModeSelected = selected.first;
          if (themeModeSelected != settings.themeMode) {
            settings.themeMode = themeModeSelected;

            String themeModeString;
            switch (themeModeSelected) {
              case ThemeMode.light:
                themeModeString = "light";
              case ThemeMode.dark:
                themeModeString = "dark";
              case ThemeMode.system:
                themeModeString = "system";
            }

            await prefs.setString("themeMode", themeModeString);

            setState(() {});
            refreshAll();
          }
        },
        showSelectedIcon: false,
      ),
    );
  }
}

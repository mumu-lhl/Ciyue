import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";

import "appearance/dictionary_switch_style_selector.dart";
import "appearance/drawer_icon_switch.dart";
import "appearance/language_selector.dart";
import "appearance/more_options_button_switch.dart";
import "appearance/searchbar_in_word_display_switch.dart";
import "appearance/searchbar_location_selector.dart";
import "appearance/tab_bar_position_selector.dart";
import "appearance/theme_color_settings_section.dart";
import "appearance/theme_selector.dart";

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appearance),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            children: [
              const LanguageSelector(),
              const ThemeSelector(),
              const ThemeColorSettingsSection(),
              const DictionarySwitchStyleSelector(),
              const SearchbarLocationSelector(),
              const TabBarPositionSelector(),
              const SearchbarInWordDisplaySwitch(),
              if (settings.advance)
                const Column(
                  children: [
                    DrawerIconSwitch(),
                    MoreOptionsButtonSwitch(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

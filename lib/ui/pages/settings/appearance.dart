import "dart:io";

import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/settings_group.dart";
import "package:material_ui/material_ui.dart";

import "appearance/content_scale_slider.dart";
import "appearance/dictionary_background_color.dart";
import "appearance/dictionary_dark_reader_switch.dart";
import "appearance/dictionary_custom_css.dart";
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.appearance)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              // See the Hunspell page: keep the last row clear of the navigation bar.
              bottom: 12 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              SettingsGroupCard(
                children: [
                  const LanguageSelector(),
                  const ThemeSelector(),
                  const ThemeColorSettingsSection(),
                  const DictionaryBackgroundColor(),
                  if (Platform.isWindows || Platform.isLinux)
                    const DictionaryDarkReaderSwitch(),
                  const DictionaryCustomCss(),
                  const ContentScaleSlider(),
                ],
              ),
              const SizedBox(height: 16),
              const SettingsGroupCard(
                children: [
                  DictionarySwitchStyleSelector(),
                  SearchbarLocationSelector(),
                  TabBarPositionSelector(),
                  SearchbarInWordDisplaySwitch(),
                ],
              ),
              if (settings.advance) ...[
                const SizedBox(height: 16),
                const SettingsGroupCard(
                  children: [DrawerIconSwitch(), MoreOptionsButtonSwitch()],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

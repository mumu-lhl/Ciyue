import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

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

class DictionarySwitchStyleSelector extends StatefulWidget {
  const DictionarySwitchStyleSelector({super.key});

  @override
  State<DictionarySwitchStyleSelector> createState() =>
      _DictionarySwitchStyleSelectorState();
}

class DrawerIconSwitch extends StatefulWidget {
  const DrawerIconSwitch({super.key});

  @override
  State<DrawerIconSwitch> createState() => _DrawerIconSwitchState();
}

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class MoreOptionsButtonSwitch extends StatefulWidget {
  const MoreOptionsButtonSwitch({super.key});

  @override
  State<MoreOptionsButtonSwitch> createState() =>
      _MoreOptionsButtonSwitchState();
}

class SearchbarInWordDisplaySwitch extends StatefulWidget {
  const SearchbarInWordDisplaySwitch({super.key});

  @override
  State<SearchbarInWordDisplaySwitch> createState() =>
      _SearchbarInWordDisplaySwitchState();
}

class SearchbarLocationSelector extends StatefulWidget {
  const SearchbarLocationSelector({super.key});

  @override
  State<SearchbarLocationSelector> createState() =>
      _SearchbarLocationSelectorState();
}

class TabBarPositionSelector extends StatefulWidget {
  const TabBarPositionSelector({super.key});

  @override
  State<TabBarPositionSelector> createState() => _TabBarPositionSelectorState();
}

class ThemeSelector extends StatefulWidget {
  const ThemeSelector({super.key});

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
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

class _LanguageSelectorState extends State<LanguageSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final languageSelected = await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.language,
          items: [
            PopupMenuItem(
                value: "system",
                child: Text(AppLocalizations.of(context)!.system)),
            const PopupMenuItem(value: "bn", child: Text("Bengali")),
            const PopupMenuItem(value: "ca", child: Text("Catalan")),
            const PopupMenuItem(value: "de", child: Text("Deutsch")),
            const PopupMenuItem(value: "es", child: Text("Español")),
            const PopupMenuItem(value: "en", child: Text("English")),
            const PopupMenuItem(value: "ru", child: Text("Русский")),
            const PopupMenuItem(value: "nb", child: Text("Bokmål")),
            const PopupMenuItem(value: "sc", child: Text("Sardinian")),
            const PopupMenuItem(value: "ta", child: Text("Tamil")),
            const PopupMenuItem(value: "fa", child: Text("فارسی")),
            const PopupMenuItem(value: "got", child: Text("Gothic")),
            const PopupMenuItem(value: "zh", child: Text("简体中文")),
            const PopupMenuItem(value: "zh_HK", child: Text("繁體中文（香港）")),
            const PopupMenuItem(value: "zh_TW", child: Text("正體中文（臺灣）")),
          ],
        );

        if (languageSelected != null) {
          settings.language = languageSelected;

          prefs.setString("language", languageSelected);

          setState(() {});
          refreshAll();
        }
      },
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(locale!.language),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
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

class _SearchbarLocationSelectorState extends State<SearchbarLocationSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final searchBarLocationSelected = await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.searchBarInAppBar,
          items: [
            PopupMenuItem(value: true, child: Text(locale.top)),
            PopupMenuItem(value: false, child: Text(locale.bottom)),
          ],
        );

        if (searchBarLocationSelected != null) {
          settings.searchBarInAppBar = searchBarLocationSelected;
          await prefs.setBool("searchBarInAppBar", searchBarLocationSelected);

          if (context.mounted) context.read<HomeModel>().update();
          setState(() {});
        }
      },
      child: ListTile(
        leading: const Icon(Icons.search),
        title: Text(locale!.searchBarLocation),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}

class _TabBarPositionSelectorState extends State<TabBarPositionSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final selected = await showMenu<TabBarPosition>(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.tabBarPosition,
          items: [
            PopupMenuItem(
              value: TabBarPosition.top,
              child: Text(locale.top),
            ),
            PopupMenuItem(
              value: TabBarPosition.bottom,
              child: Text(locale.bottom),
            ),
          ],
        );

        if (selected != null && selected != settings.tabBarPosition) {
          await settings.setTabBarPosition(selected);
          setState(() {});
        }
      },
      child: ListTile(
        leading: const Icon(Icons.tab),
        title: Text(locale.tabBarPosition),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}

class _ThemeSelectorState extends State<ThemeSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final themeModeSelected = await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.themeMode,
          items: [
            PopupMenuItem(value: ThemeMode.light, child: Text(locale.light)),
            PopupMenuItem(value: ThemeMode.dark, child: Text(locale.dark)),
            PopupMenuItem(value: ThemeMode.system, child: Text(locale.system)),
          ],
        );

        if (themeModeSelected != null) {
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

          prefs.setString("themeMode", themeModeString);

          setState(() {});
          refreshAll();
        }
      },
      child: ListTile(
        leading: const Icon(Icons.light_mode),
        title: Text(locale!.theme),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}

class _DictionarySwitchStyleSelectorState
    extends State<DictionarySwitchStyleSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final selected = await showMenu<DictionarySwitchStyle>(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.dictionarySwitchStyle,
          items: [
            PopupMenuItem(
              value: DictionarySwitchStyle.expansion,
              child: Text(locale.expansion),
            ),
            PopupMenuItem(
              value: DictionarySwitchStyle.tag,
              child: Text(locale.tag),
            ),
          ],
        );

        if (selected != null && selected != settings.dictionarySwitchStyle) {
          await settings.setDictionarySwitchStyle(selected);
          setState(() {});
        }
      },
      child: ListTile(
        leading: const Icon(Icons.style),
        title: Text(locale.dictionarySwitchStyle),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}

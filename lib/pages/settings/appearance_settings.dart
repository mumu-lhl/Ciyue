import "package:ciyue/main.dart";
import "package:ciyue/services/settings.dart";
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
      body: ListView(
        children: const [
          SearchbarLocationSelector(),
          TabBarPositionSelector(),
          SearchbarInWordDisplaySwitch(),
          DrawerIconSwitch(),
          MoreOptionsButtonSwitch(),
        ],
      ),
    );
  }
}

class SearchbarLocationSelector extends StatefulWidget {
  const SearchbarLocationSelector({super.key});

  @override
  State<SearchbarLocationSelector> createState() =>
      _SearchbarLocationSelectorState();
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

class TabBarPositionSelector extends StatefulWidget {
  const TabBarPositionSelector({super.key});

  @override
  State<TabBarPositionSelector> createState() => _TabBarPositionSelectorState();
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

class DrawerIconSwitch extends StatefulWidget {
  const DrawerIconSwitch({super.key});

  @override
  State<DrawerIconSwitch> createState() => _DrawerIconSwitchState();
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

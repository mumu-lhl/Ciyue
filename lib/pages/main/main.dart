import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/pages/main/home.dart";
import "package:ciyue/pages/main/settings.dart";
import "package:ciyue/pages/main/wordbook.dart";
import "package:ciyue/settings.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

late VoidCallback clearSearchWord;

class Home extends StatefulWidget {
  final String searchWord;

  const Home({super.key, required this.searchWord});

  @override
  State<Home> createState() => _HomeState();
}

class MoreOptionsDialog extends StatefulWidget {
  const MoreOptionsDialog({super.key});

  @override
  State<MoreOptionsDialog> createState() => _MoreOptionsDialogState();
}

class _HomeState extends State<Home> {
  late String searchWord;
  var _currentIndex = 0;

  final textFieldController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final page = [
      HomeScreen(searchWord: searchWord),
      const WordBookScreen(),
      const SettingsScreen()
    ];

    return Scaffold(
      appBar: buildAppBar(context),
      body: Column(
        children: [
          Expanded(child: page[_currentIndex]),
          if (_currentIndex == 0 && !settings.searchBarInAppBar)
            buildSearchBar(context),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedIndex: _currentIndex,
        destinations: buildDestinations(context),
      ),
      drawer: buildDrawer(),
    );
  }

  AppBar? buildAppBar(BuildContext context) {
    if (!dictManager.isEmpty && _currentIndex == 0) {
      final searchBar =
          settings.searchBarInAppBar ? buildSearchBar(context) : null;
      return AppBar(
        title: searchBar,
        automaticallyImplyLeading: settings.showSidebarIcon,
        actions: [
          buildMoreButton(context),
        ],
      );
    }
    return null;
  }

  List<NavigationDestination> buildDestinations(BuildContext context) {
    return <NavigationDestination>[
      NavigationDestination(
          icon: const Icon(Icons.home),
          label: AppLocalizations.of(context)!.home),
      NavigationDestination(
          icon: const Icon(Icons.book),
          label: AppLocalizations.of(context)!.wordBook),
      NavigationDestination(
          icon: const Icon(Icons.settings),
          label: AppLocalizations.of(context)!.settings),
    ];
  }

  Drawer buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          for (final group in dictManager.groups)
            ListTile(
              leading: group.id == dictManager.groupId
                  ? const Icon(Icons.circle, size: 10)
                  : const Icon(Icons.circle_outlined, size: 10),
              title: Text(group.name == "Default"
                  ? AppLocalizations.of(context)!.default_
                  : group.name),
              onTap: () async {
                context.pop();
                await dictManager.setCurrentGroup(group.id);
              },
            ),
        ],
      ),
    );
  }

  IconButton buildMoreButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () async {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return const MoreOptionsDialog();
          },
        );
      },
    );
  }

  IconButton? buildRemoveButton() {
    if (searchWord == "") {
      return null;
    } else {
      return IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          textFieldController.clear();
          setState(() {
            searchWord = "";
          });
        },
      );
    }
  }

  Widget buildSearchBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
        child: TextField(
          autofocus: widget.searchWord != "",
          onTapOutside: (pointerDownEvent) {
            FocusScope.of(context).unfocus();
          },
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.search,
              suffixIcon: buildRemoveButton()),
          controller: textFieldController,
          onChanged: (text) async {
            setState(() {
              searchWord = text;
            });
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    searchWord = widget.searchWord;
    textFieldController.text = widget.searchWord;

    clearSearchWord = () {
      textFieldController.clear();
      setState(() {
        searchWord = "";
      });
    };
  }
}

class _MoreOptionsDialogState extends State<MoreOptionsDialog> {
  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(AppLocalizations.of(context)!.more),
      children: [
        SimpleDialogOption(
          child: CheckboxListTile(
            value: settings.autoRemoveSearchWord,
            onChanged: (value) async {
              if (value != null) {
                settings.autoRemoveSearchWord = value;
                await prefs.setBool("autoRemoveSearchWord", value);
                setState(() {});
              }
            },
            title: Text(AppLocalizations.of(context)!.autoRemoveSearchWord),
          ),
        ),
      ],
    );
  }
}

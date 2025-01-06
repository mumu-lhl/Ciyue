import "package:ciyue/dictionary.dart";
import "package:ciyue/pages/main/home.dart";
import "package:ciyue/pages/main/settings.dart";
import "package:ciyue/pages/main/wordbook.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  var searchWord = "";

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
      body: page[_currentIndex],
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
      return AppBar(title: buildSearchBar(context));
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
              title: Text(group.name),
              onTap: () async {
                context.pop();
                await dictManager.setCurrentGroup(group.id);
              },
            ),
        ],
      ),
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

  SafeArea buildSearchBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
        child: TextField(
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
}

import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";

import "../database.dart";
import "../main.dart";
import "../screens/home.dart";
import "../screens/settings.dart";
import "../screens/wordbook.dart";

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  var searchResult = <DictionaryData>[];
  var searchWord = "";

  var _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    PreferredSizeWidget? appBar;

    if (currentDictionaryPath != null && _currentIndex == 0) {
      final flexibleSpace = SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
          child: TextField(
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.search),
            onChanged: (text) async {
              final result = await dictionary!.searchWord(text);

              setState(() {
                searchResult = result;
                searchWord = text;
              });
            },
          ),
        ),
      );

      appBar = AppBar(flexibleSpace: flexibleSpace);
    }

    final destinations = <NavigationDestination>[
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

    final page = [
      HomeScreen(searchWord: searchWord, searchResult: searchResult),
      const WordBookScreen(),
      const SettingsScreen()
    ];

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: appBar,
        body: page[_currentIndex],
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: (int index) {
            setState(() {
              _currentIndex = index;

              if (index != 0) {
                searchWord = "";
                searchResult = [];
              }
            });
          },
          selectedIndex: _currentIndex,
          destinations: destinations,
        ),
      ),
    );
  }
}

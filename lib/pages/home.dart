import "package:ciyue/database/dictionary.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/screens/home.dart";
import "package:ciyue/screens/settings.dart";
import "package:ciyue/screens/wordbook.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  var searchResult = <DictionaryData>[];
  var searchWord = "";

  var _currentIndex = 0;

  final textFieldController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    PreferredSizeWidget? appBar;

    if (dict.path != null && _currentIndex == 0) {
      Widget? removeButton;
      if (searchWord != "") {
        removeButton = IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            textFieldController.clear();
            setState(() {
              searchWord = "";
              searchResult.clear();
            });
          },
        );
      }

      final flexibleSpace = SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
          child: TextField(
            onTapOutside: (pointerDownEvent) {
              FocusScope.of(context).unfocus();
            },
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.search,
                suffixIcon: removeButton),
            controller: textFieldController,
            onChanged: (text) async {
              final result = await dict.db!.searchWord(text);

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

    return Scaffold(
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
    );
  }
}

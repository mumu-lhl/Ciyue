import "package:ciyue/database/dictionary.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/pages/main/home.dart";
import "package:ciyue/pages/main/settings.dart";
import "package:ciyue/pages/main/wordbook.dart";
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

    if (!dictManager.isEmpty && _currentIndex == 0) {
      final flexibleSpace = SafeArea(
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
              final searchers = <Future<List<DictionaryData>>>[];
              for (final dict in dictManager.dicts.values) {
                searchers.add(dict.db.searchWord(text));
              }
              final futureResult = await Future.wait(searchers);
              final result = [for (final i in futureResult) ...i];
              result.sort((a, b) => a.key.compareTo(b.key));

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
          });
        },
        selectedIndex: _currentIndex,
        destinations: destinations,
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
            searchResult.clear();
          });
        },
      );
    }
  }
}

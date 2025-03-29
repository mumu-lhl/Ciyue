import "package:ciyue/pages/main/ai_translate_page.dart";
import "package:ciyue/pages/main/home.dart";
import "package:ciyue/pages/main/settings.dart";
import "package:ciyue/pages/main/wordbook.dart";
import "package:flutter/material.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";

class MainPage {
  static void Function(int)? _setScreenIndex;

  static void Function(int) get setScreenIndex => _setScreenIndex!;
  static set setScreenIndex(void Function(int) callback) =>
      _setScreenIndex = callback;
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late String searchWord;
  var _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final page = [
      const HomeScreen(),
      const AiTranslatePage(),
      const WordBookScreen(),
      const SettingsScreen()
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: page[_currentIndex]),
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
    );
  }

  List<NavigationDestination> buildDestinations(BuildContext context) {
    return <NavigationDestination>[
      NavigationDestination(
          icon: const Icon(Icons.home),
          label: AppLocalizations.of(context)!.home),
      NavigationDestination(
          icon: const Icon(Icons.translate),
          label: AppLocalizations.of(context)!.translate),
      NavigationDestination(
          icon: const Icon(Icons.book),
          label: AppLocalizations.of(context)!.wordBook),
      NavigationDestination(
          icon: const Icon(Icons.settings),
          label: AppLocalizations.of(context)!.settings),
    ];
  }


  @override
  void initState() {
    super.initState();

    MainPage.setScreenIndex = (int index) {
      setState(() {
        _currentIndex = index;
      });
    };
  }
}


import "package:ciyue/pages/main/ai_translate_page.dart";
import "package:ciyue/pages/main/home.dart";
import "package:ciyue/pages/main/settings.dart";
import "package:ciyue/pages/main/wordbook.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class MainPage {
  static void Function(int)? _setScreenIndex;

  static void Function(int) get setScreenIndex => _setScreenIndex!;
  static set setScreenIndex(void Function(int) callback) =>
      _setScreenIndex = callback;
}

class _HomeState extends State<Home> {
  late String searchWord;
  var _currentIndex = 0;
  final _pages = [
    const HomeScreen(),
    const AiTranslatePage(),
    const WordBookScreen(),
    const SettingsScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildBody(),
      bottomNavigationBar: buildNavigationBar(),
    );
  }

  Widget buildBody() {
    return MediaQuery.of(context).size.width > 600
        ? Row(
            children: [
              NavigationRail(
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final destination in buildCommonDestinations())
                    NavigationRailDestination(
                      icon: destination.$1,
                      label: Text(destination.$2),
                    )
                ],
                selectedIndex: _currentIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                leading: const SizedBox(),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
            ],
          )
        : IndexedStack(
            index: _currentIndex,
            children: _pages,
          );
  }

  List<(Icon, String)> buildCommonDestinations() {
    return [
      (const Icon(Icons.home), AppLocalizations.of(context)!.home),
      (const Icon(Icons.translate), AppLocalizations.of(context)!.translate),
      (const Icon(Icons.book), AppLocalizations.of(context)!.wordBook),
      (const Icon(Icons.settings), AppLocalizations.of(context)!.settings)
    ];
  }

  NavigationBar? buildNavigationBar() {
    return MediaQuery.of(context).size.width < 600
        ? NavigationBar(
            onDestinationSelected: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            selectedIndex: _currentIndex,
            destinations: [
              for (final destination in buildCommonDestinations())
                NavigationDestination(
                  icon: destination.$1,
                  label: destination.$2,
                )
            ],
          )
        : null;
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

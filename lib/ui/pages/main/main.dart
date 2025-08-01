import "package:ciyue/ui/pages/translate/translate_page.dart";
import "package:ciyue/ui/pages/main/home.dart";
import "package:ciyue/ui/pages/main/settings.dart";
import "package:ciyue/ui/pages/main/wordbook.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter/material.dart";
import "package:ciyue/services/toast.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

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
  DateTime? _lastPressedAt;

  // Using FocusScope for each page within the IndexedStack.
  // Why?
  // IndexedStack keeps all child pages' states (including their FocusNodes) alive, even when invisible.
  // When returning from a pushed route (popping back to a page within the IndexedStack),
  // Flutter's focus restoration logic might incorrectly grant focus to a FocusNode
  // on an *inactive* (but still existing in the tree) page within the IndexedStack.
  // Wrapping each page in its own FocusScope creates distinct focus boundaries. This ensures
  // that focus restoration correctly targets the scope of the *currently visible* page after a pop,
  // preventing focus from unexpectedly jumping to an element on an invisible page.
  final _pages = [
    FocusScope(child: const HomeScreen()),
    FocusScope(child: const AiTranslatePage()),
    FocusScope(child: const WordBookScreen()),
    FocusScope(child: const SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.sizeOf(context).aspectRatio;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) {
          return;
        }

        final now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ToastService.show(
            AppLocalizations.of(context)!.pressAgainToExit,
            context,
            type: ToastType.info,
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          body: ratio > 1.0
              ? Row(
                  children: [
                    NavigationRail(
                      extended: ratio > 1.5,
                      labelType: ratio > 1.5
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      destinations: [
                        for (final destination in buildCommonDestinations())
                          NavigationRailDestination(
                            icon: destination.$1,
                            label: Text(destination.$2),
                          )
                      ],
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (int index) {
                        if (index != 0) {
                          FocusScope.of(context).unfocus();
                        } else {
                          context
                              .read<HomeModel>()
                              .searchBarFocusNode
                              .requestFocus();
                        }
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
                ),
          bottomNavigationBar: ratio <= 1.0
              ? NavigationBar(
                  onDestinationSelected: (int index) {
                    setState(() {
                      _currentIndex = index;
                    });
                    FocusScope.of(context).unfocus();
                    if (index != 0) {
                      context.read<HomeModel>().searchBarFocusNode.unfocus();
                    } else {
                      context
                          .read<HomeModel>()
                          .searchBarFocusNode
                          .requestFocus();
                    }
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
              : null,
        ),
      ),
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

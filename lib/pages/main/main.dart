import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/pages/main/home.dart";
import "package:ciyue/pages/main/settings.dart";
import "package:ciyue/pages/main/wordbook.dart";
import "package:ciyue/settings.dart";
import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

class MainPage {
  static VoidCallback? _clearSearchWord;
  static VoidCallback? _enableAutofocusOnce;
  static void Function(int)? _setScreenIndex;
  static bool callEnableAutofocusOnce = false;

  static VoidCallback get clearSearchWord => _clearSearchWord!;
  static set clearSearchWord(VoidCallback callback) =>
      _clearSearchWord = callback;

  static VoidCallback get enableAutofocusOnce => _enableAutofocusOnce!;
  static set enableAutofocusOnce(VoidCallback callback) =>
      _enableAutofocusOnce = callback;

  static void Function(int) get setScreenIndex => _setScreenIndex!;
  static set setScreenIndex(void Function(int) callback) =>
      _setScreenIndex = callback;
}

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
  var _autofocus = false;

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
            Padding(
                padding: const EdgeInsets.only(
                    left: 20, right: 20, bottom: 10, top: 10),
                child: buildSearchBar(context)),
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
          if (settings.showMoreOptionsButton) buildMoreButton(context),
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
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            DrawerHeader(
              child: Text(
                "Dictionary Groups",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            for (final group in dictManager.groups)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                elevation: 0,
                child: ListTile(
                  leading: group.id == dictManager.groupId
                      ? const Icon(Icons.radio_button_checked, size: 20)
                      : const Icon(Icons.radio_button_unchecked, size: 20),
                  title: Text(group.name == "Default"
                      ? AppLocalizations.of(context)!.default_
                      : group.name),
                  onTap: () async {
                    context.pop();
                    await dictManager.setCurrentGroup(group.id);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Padding buildMoreButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () async {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return const MoreOptionsDialog();
            },
          );
        },
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

  Widget buildSearchBar(BuildContext context) {
    final autofocus = _autofocus;
    _autofocus = false;

    return SafeArea(
      child: Center(
        child: SearchBar(
          autoFocus: autofocus,
          onTapOutside: (pointerDownEvent) {
            FocusScope.of(context).unfocus();
          },
          hintText: AppLocalizations.of(context)!.search,
          controller: textFieldController,
          elevation: WidgetStateProperty.all(1),
          constraints:
              const BoxConstraints(maxHeight: 42, minHeight: 42, maxWidth: 500),
          onChanged: (text) async {
            setState(() {
              searchWord = text;
            });
          },
          leading: const Icon(Icons.search),
          trailing: [
            if (searchWord.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  textFieldController.clear();
                  setState(() {
                    searchWord = "";
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    searchWord = widget.searchWord;
    textFieldController.text = widget.searchWord;

    MainPage.clearSearchWord = () {
      textFieldController.clear();
      setState(() {
        searchWord = "";
      });
    };
    MainPage.setScreenIndex = (int index) {
      setState(() {
        _currentIndex = index;
      });
    };
    MainPage.enableAutofocusOnce = () {
      setState(() {
        _autofocus = true;
      });
    };
    if (MainPage.callEnableAutofocusOnce) {
      MainPage.enableAutofocusOnce();
      MainPage.callEnableAutofocusOnce = false;
    }
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

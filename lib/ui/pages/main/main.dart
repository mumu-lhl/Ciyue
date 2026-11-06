import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/floating_window.dart";
import "package:ciyue/ui/pages/main/home/app_bar.dart";
import "package:ciyue/ui/pages/main/home/drawer.dart";
import "package:ciyue/ui/pages/main/home/scaffold.dart";
import "package:ciyue/ui/pages/main/home_top_nav_bar.dart";
import "package:ciyue/ui/pages/translate/translate_page.dart";
import "package:ciyue/ui/pages/main/settings.dart";
import "package:ciyue/ui/pages/main/wordbook.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";
import "package:ciyue/services/toast.dart";
import "package:flutter/services.dart";
import "package:home_widget/home_widget.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/utils.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class MainPage {
  static void Function(int)? _setScreenIndex;

  static void Function(int) get setScreenIndex => _setScreenIndex!;
  static set setScreenIndex(void Function(int) callback) =>
      _setScreenIndex = callback;
}

class _HomeState extends ConsumerState<Home> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late String searchWord;
  var _currentIndex = 0;
  // null = follow the automatic size rule; otherwise the reader's manual
  // choice for this run (horizontal top row / vertical rail).
  bool? _navStyleOverride;
  DateTime? _lastPressedAt;

  // Using FocusScope for each page within the IndexedStack.
  // Why?
  // IndexedStack keeps all child pages' states (including their FocusNodes) alive, even when invisible.
  // When returning from a pushed route (popping back to a page within the IndexedStack),
  // Flutter's focus restoration logic might incorrectly grant focus to a FocusNode
  // on an *inactive* (but still existing in the tree) page within the IndexedStack.
  // Wrapping each page in its own FocusScope creates distinct focus boundaries.
  // Setting canRequestFocus to false on inactive pages ensures that focus restoration
  // cannot reach into invisible pages, preventing the IME from popping up unexpectedly.
  List<Widget> get _pages => [
    FocusScope(canRequestFocus: _currentIndex == 0, child: const HomeScreen()),
    FocusScope(
      canRequestFocus: _currentIndex == 1,
      child: const AiTranslatePage(),
    ),
    FocusScope(
      canRequestFocus: _currentIndex == 2,
      child: const WordBookScreen(),
    ),
    FocusScope(
      canRequestFocus: _currentIndex == 3,
      child: const SettingsScreen(),
    ),
  ];

  StreamSubscription<Uri?>? _widgetClickSubscription;

  void _handleWidgetClick(Uri? uri) {
    if (uri?.host == "search") {
      router.go("/");
      setState(() {
        _currentIndex = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(homeModelProvider).focusSearchBar();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.sizeOf(context).aspectRatio;
    final useDesktop = useDesktopLayout(context);
    // A manual toggle only overrides the size rule for this run; portrait
    // and compact layouts never show either of these navigation styles.
    final useTopNav =
        useDesktop && (_navStyleOverride ?? useTopNavBar(context));
    void toggleNavStyle() {
      final auto = useTopNavBar(context);
      setState(() {
        _navStyleOverride = !(_navStyleOverride ?? auto);
      });
    }

    final historyModel = ref.watch(historyModelProvider);
    ref.watch(homeModelProvider.select((value) => value.state));
    ref.watch(dictManagerModelProvider.select((value) => value.isEmpty));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) {
          return;
        }

        if (runningInFloatingWindow) {
          unawaited(dismissFloatingWindow());
          return;
        }

        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.pop(context);
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
          key: _scaffoldKey,
          // With a vertical rail the rail has to reach the very top of the
          // window, so the home app bar moves into the content column to its
          // right instead of spanning the full width above it.
          appBar: useTopNav
              ? HomeTopNavBar(
                  currentIndex: _currentIndex,
                  destinations: buildCommonDestinations(),
                  onDestinationSelected: _selectDestination,
                  onToggleNavStyle: toggleNavStyle,
                )
              : ratio > 1.0
              ? null
              : _currentIndex == 0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight),
                  child: (!dictManager.isEmpty || settings.aiExplainWord)
                      ? const HomeAppBar()
                      : const SizedBox.shrink(),
                )
              : null,
          drawer: _currentIndex == 0 && !historyModel.isSelecting
              ? const HomeDrawer()
              : null,
          // Top row: destinations live in the app bar and the page gets the
          // full width. Rail: it spans the full height, with the home app bar
          // as the first row of the content column to its right.
          body: useTopNav
              ? IndexedStack(index: _currentIndex, children: _pages)
              : ratio > 1.0
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
                          ),
                      ],
                      selectedIndex: _currentIndex,
                      onDestinationSelected: _selectDestination,
                      leading: useDesktop
                          ? IconButton(
                              tooltip: AppLocalizations.of(context)!
                                  .switchToTopNavigation,
                              icon: const Icon(Icons.swap_horiz),
                              onPressed: toggleNavStyle,
                            )
                          : const SizedBox(),
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                      child: Column(
                        children: [
                          if (_currentIndex == 0 &&
                              (!dictManager.isEmpty || settings.aiExplainWord))
                            const HomeAppBar(),
                          Expanded(
                            child: IndexedStack(
                              index: _currentIndex,
                              children: _pages,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : IndexedStack(index: _currentIndex, children: _pages),
          bottomNavigationBar: ratio <= 1.0
              ? NavigationBar(
                  onDestinationSelected: (int index) {
                    setState(() {
                      _currentIndex = index;
                    });
                    FocusScope.of(context).unfocus();
                    if (index != 0) {
                      ref.read(homeModelProvider).searchBarFocusNode.unfocus();
                    } else {
                      ref
                          .read(homeModelProvider)
                          .searchBarFocusNode
                          .requestFocus();
                    }
                  },
                  selectedIndex: _currentIndex,
                  destinations: [
                    for (final destination in buildCommonDestinations())
                      _destination(context, destination),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  void _selectDestination(int index) {
    if (index != 0) {
      FocusScope.of(context).unfocus();
    } else {
      ref.read(homeModelProvider).searchBarFocusNode.requestFocus();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  List<(Icon, String)> buildCommonDestinations() {
    return [
      (const Icon(Icons.home), AppLocalizations.of(context)!.home),
      (const Icon(Icons.translate), AppLocalizations.of(context)!.translate),
      (const Icon(Icons.book), AppLocalizations.of(context)!.wordBook),
      (const Icon(Icons.settings), AppLocalizations.of(context)!.settings),
    ];
  }

  /// The navigation bar does not limit the number of lines of a label, so a
  /// long translation grows the bar past the bottom of the screen and the
  /// destinations disappear. A label that does not fit into a destination is
  /// therefore left out and shown in a tooltip on the icon instead.
  NavigationDestination _destination(
    BuildContext context,
    (Icon, String) item,
  ) {
    final (icon, label) = item;
    if (_labelFits(context, label)) {
      return NavigationDestination(icon: icon, label: label);
    }
    return NavigationDestination(
      icon: icon,
      // The label is rendered as a plain text without a line limit, so an
      // empty one keeps the bar at its normal height. The wording stays
      // reachable through the tooltip.
      label: "",
      tooltip: label,
    );
  }

  bool _labelFits(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    // A destination is a quarter of the screen wide, so this is about what
    // its label can show without wrapping.
    return painter.width <= 70;
  }

  @override
  void initState() {
    super.initState();

    MainPage.setScreenIndex = (int index) {
      setState(() {
        _currentIndex = index;
      });
    };

    if (Platform.isAndroid) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetClick);
      _widgetClickSubscription = HomeWidget.widgetClicked.listen(
        _handleWidgetClick,
      );
    }
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    super.dispose();
  }
}

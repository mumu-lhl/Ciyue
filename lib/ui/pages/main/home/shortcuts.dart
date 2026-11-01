import "dart:async";
import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:ciyue/ui/core/word_display/buttons.dart";
import "package:ciyue/ui/core/word_display/content_scale_script.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

/// The number keys, in the order they appear on a keyboard.
const _digitKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

/// The shortcuts the home page binds.
///
/// Both the Flutter focus tree and the key bridge of the entry WebView run
/// this table. An Android WebView holds the native focus and never lets
/// Flutter see the keys, so the bridge has to reach the same actions by
/// itself instead of relying on [CallbackShortcuts].
Map<SingleActivator, VoidCallback> homeShortcutBindings(
  WidgetRef ref,
  BuildContext context,
) {
  final homeModel = ref.read(homeModelProvider);
  final history = ref.read(historyModelProvider).history;
  final activeWord =
      homeModel.selectedWord ?? (history.isEmpty ? null : history.first.word);

  return {
    const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
      _focusNode(pageSearchFocusNode ?? homeModel.searchBarFocusNode);
    },
    const SingleActivator(LogicalKeyboardKey.keyT, control: true):
        homeModel.newTab,
    const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
      if (homeModel.tabs.isNotEmpty && homeModel.activeTabIndex >= 0) {
        homeModel.closeTab(homeModel.activeTabIndex);
      }
    },
    const SingleActivator(LogicalKeyboardKey.tab, control: true):
        homeModel.nextTab,
    const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
        homeModel.previousTab,
    const SingleActivator(LogicalKeyboardKey.arrowDown, control: true): () {
      if (!homeModel.searchBarFocusNode.hasFocus) {
        _selectAdjacentHistory(ref, homeModel, 1);
      }
    },
    const SingleActivator(LogicalKeyboardKey.arrowUp, control: true): () {
      if (!homeModel.searchBarFocusNode.hasFocus) {
        _selectAdjacentHistory(ref, homeModel, -1);
      }
    },
    const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
      if (activeWord != null && activeWord.isNotEmpty) {
        playWordPronunciation(context, activeWord);
      }
    },
    const SingleActivator(LogicalKeyboardKey.escape): () =>
        _toggleSearchFocus(ref),
    const SingleActivator(LogicalKeyboardKey.pageDown, control: true):
        homeModel.nextTab,
    const SingleActivator(LogicalKeyboardKey.pageUp, control: true):
        homeModel.previousTab,
    const SingleActivator(LogicalKeyboardKey.pageDown): () =>
        _pageEntry(ref, "PageDown"),
    const SingleActivator(LogicalKeyboardKey.pageUp): () =>
        _pageEntry(ref, "PageUp"),
    const SingleActivator(
      LogicalKeyboardKey.keyS,
      control: true,
      shift: true,
    ): () =>
        unawaited(ref.read(audioModelProvider).stopAudio()),
    const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
        changeContentScale(ref.read(settingsProvider), 0.1),
    const SingleActivator(
      LogicalKeyboardKey.equal,
      control: true,
      shift: true,
    ): () =>
        changeContentScale(ref.read(settingsProvider), 0.1),
    const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
        changeContentScale(ref.read(settingsProvider), -0.1),
    const SingleActivator(LogicalKeyboardKey.digit0, control: true): () =>
        resetContentScale(ref.read(settingsProvider)),
    ..._dictionaryTabShortcuts(ref, homeModel),
    ..._groupShortcuts(ref),
  };
}

/// Moves the focus into the inline search box.
///
/// The search view is a route of its own, and opening it here would take the
/// focus out of the home page, where the shortcuts live. Typing opens it the
/// normal way.
///
void _focusNode(FocusNode node, {bool selectAll = false}) {
  talker.info(
    "focusNode: attached=${node.context != null} selectAll=$selectAll",
  );
  // Run after the current key event has been dispatched: the text field's
  // dismiss intent can otherwise unfocus the box right after this returns.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!node.hasFocus) {
      FocusManager.instance.primaryFocus?.unfocus();
      node.requestFocus();
    }
    if (selectAll) {
      // The focus node only gets a context once the field is focused, so the
      // selection has to wait for the next frame as well.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        selectAllTextInField(node);
      });
    }
  });
}

void _focusNodeAndSelectAll(FocusNode node) {
  _focusNode(node, selectAll: true);
}

/// Moves the focus between the search box and the entry.
///
/// The first Esc focuses the box and selects its text; the next one hands the
/// focus back to the entry, so the same key walks between the two places a
/// reader moves in.
void _toggleSearchFocus(WidgetRef ref) {
  final activeController = activeSearchController;
  if (activeController != null &&
      activeController.isAttached &&
      activeController.isOpen) {
    activeController.closeView(null);
    return;
  }
  final homeModel = ref.read(homeModelProvider);
  if (homeModel.searchController.isAttached &&
      homeModel.searchController.isOpen) {
    homeModel.searchController.closeView(null);
    return;
  }
  // The box the reader last used may be the home page's or the entry page's;
  // both register themselves here when they take the focus.
  final focused = activeSearchFocusNode;
  talker.info(
    "esc toggle: focused=${focused?.hasFocus} dict=$activeEntryDictId",
  );
  if (focused != null && focused.hasFocus) {
    focused.unfocus();
    focusActiveEntrySoon();
    return;
  }
  final target =
      pageSearchFocusNode ?? ref.read(homeModelProvider).searchBarFocusNode;
  _focusNodeAndSelectAll(target);
}

/// Moves the selected word through the history by [delta] entries.
///
/// The plain arrow keys are left to Flutter's focus traversal, so this lives
/// on `Ctrl`+`↑`/`Ctrl`+`↓`.
void _selectAdjacentHistory(WidgetRef ref, HomeModel homeModel, int delta) {
  final history = ref.read(historyModelProvider).history;
  if (history.isEmpty) return;

  final currentWord = homeModel.selectedWord ?? history.first.word;
  final currentIndex = history.indexWhere((item) => item.word == currentWord);

  int newIndex;
  if (currentIndex == -1) {
    newIndex = delta > 0 ? 0 : history.length - 1;
  } else {
    newIndex = (currentIndex + delta).clamp(0, history.length - 1);
  }

  homeModel.selectedWord = history[newIndex].word;
}

/// Binds `Alt`+0..9 to the dictionary tabs of the entry.
///
/// The tabs live inside the entry page, but the shortcut has to sit next
/// to the other app-level ones so that it works wherever the focus is.
/// The entry registers its tab controller, which is where the action ends
/// up.
///
/// `Alt`+0 jumps to the AI explanation, `Alt`+1..9 to the first nine
/// dictionaries. A key that names no tab does nothing: in the expansion
/// layout there are no tabs at all, and a number past the last dictionary
/// has nowhere to go.
Map<SingleActivator, VoidCallback> _dictionaryTabShortcuts(
  WidgetRef ref,
  HomeModel homeModel,
) {
  final shortcuts = <SingleActivator, VoidCallback>{};
  for (var number = 0; number < _digitKeys.length; number++) {
    shortcuts[SingleActivator(_digitKeys[number], alt: true)] = () {
      // Typing in the search box must not jump to another dictionary.
      if (homeModel.searchBarFocusNode.hasFocus) return;

      final tabController = dictTabController;
      if (tabController == null) return;

      final settings = ref.read(settingsProvider);
      final dictionaryCount =
          tabController.length - (settings.aiExplainWord ? 1 : 0);
      final index = dictTabIndexForNumber(
        number: number,
        aiExplainWord: settings.aiExplainWord,
        dictionaryCount: dictionaryCount,
      );
      if (index == null) return;
      try {
        tabController.animateTo(index);
      } catch (_) {
        // The tab bar was torn down between the check and the call.
      }
    };
  }
  return shortcuts;
}

/// Binds `Ctrl`+` and `Ctrl`+1..9 to the dictionary groups.
///
/// The groups are numbered by the position they are listed in, so `Ctrl`+`
/// reaches the first one -- the default group -- and `Ctrl`+1..9 the
/// second to the tenth. A number past the last group does nothing.
Map<SingleActivator, VoidCallback> _groupShortcuts(WidgetRef ref) {
  final shortcuts = <SingleActivator, VoidCallback>{
    const SingleActivator(LogicalKeyboardKey.backquote, control: true): () =>
        _switchToGroup(ref, 1),
  };
  for (var number = 1; number < _digitKeys.length; number++) {
    shortcuts[SingleActivator(_digitKeys[number], control: true)] = () =>
        _switchToGroup(ref, number + 1);
  }
  return shortcuts;
}

void _switchToGroup(WidgetRef ref, int position) {
  unawaited(ref.read(dictManagerModelProvider).switchToGroupAt(position));
}

/// Pages the entry in the expansion layout.
///
/// There the WebView is as tall as its content and has nothing of its own
/// to scroll, so the outer scroll container has to do it. In the tab layout
/// the WebView scrolls on its own and the keys are left to it.
void _pageEntry(WidgetRef ref, String key) {
  final settings = ref.read(settingsProvider);
  if (settings.dictionarySwitchStyle != DictionarySwitchStyle.expansion) {
    return;
  }
  expansionPageHandler?.call(key);
}

/// The activator a key bridge message names, or null when the code is not
/// bound or the message is malformed.
///
/// The bridge script sends the DOM `code` plus the modifier state, so the
/// bridge can reach the same table [homeShortcutBindings] builds.
SingleActivator? bridgeShortcutActivator(String payload) {
  Object? data;
  try {
    data = jsonDecode(payload);
  } on FormatException {
    return null;
  }
  if (data is! Map) return null;
  final key = _logicalKeyForCode(data["code"]?.toString() ?? "");
  if (key == null) return null;
  return SingleActivator(
    key,
    control: data["ctrl"] == true,
    alt: data["alt"] == true,
    shift: data["shift"] == true,
    meta: data["meta"] == true,
  );
}

/// The action bound to [activator], matched by its keys.
///
/// [SingleActivator] has no value equality, so a constructed activator can
/// never find its binding with a map lookup.
VoidCallback? shortcutActionFor(
  Map<SingleActivator, VoidCallback> bindings,
  SingleActivator activator,
) {
  for (final entry in bindings.entries) {
    final candidate = entry.key;
    if (candidate.trigger == activator.trigger &&
        candidate.control == activator.control &&
        candidate.alt == activator.alt &&
        candidate.shift == activator.shift &&
        candidate.meta == activator.meta) {
      return entry.value;
    }
  }
  return null;
}

/// The key a DOM `KeyboardEvent.code` names, or null for a code the home page
/// does not bind.
LogicalKeyboardKey? _logicalKeyForCode(String code) {
  switch (code) {
    case "KeyF":
      return LogicalKeyboardKey.keyF;
    case "KeyT":
      return LogicalKeyboardKey.keyT;
    case "KeyW":
      return LogicalKeyboardKey.keyW;
    case "KeyR":
      return LogicalKeyboardKey.keyR;
    case "KeyS":
      return LogicalKeyboardKey.keyS;
    case "Tab":
      return LogicalKeyboardKey.tab;
    case "PageUp":
      return LogicalKeyboardKey.pageUp;
    case "PageDown":
      return LogicalKeyboardKey.pageDown;
    case "ArrowUp":
      return LogicalKeyboardKey.arrowUp;
    case "ArrowDown":
      return LogicalKeyboardKey.arrowDown;
    case "Escape":
      return LogicalKeyboardKey.escape;
    case "Backquote":
      return LogicalKeyboardKey.backquote;
    case "Digit0":
      return LogicalKeyboardKey.digit0;
    case "Digit1":
      return LogicalKeyboardKey.digit1;
    case "Digit2":
      return LogicalKeyboardKey.digit2;
    case "Digit3":
      return LogicalKeyboardKey.digit3;
    case "Digit4":
      return LogicalKeyboardKey.digit4;
    case "Digit5":
      return LogicalKeyboardKey.digit5;
    case "Digit6":
      return LogicalKeyboardKey.digit6;
    case "Digit7":
      return LogicalKeyboardKey.digit7;
    case "Digit8":
      return LogicalKeyboardKey.digit8;
    case "Digit9":
      return LogicalKeyboardKey.digit9;
  }
  return null;
}

/// Handles Esc for one page: closes the search view, moves the focus into the
/// page's search box, or hands it back to the entry.
///
/// The search view is a route of its own: it sits above the page's
/// [CallbackShortcuts] and does not handle Esc itself, so once it was opened
/// the key could neither dismiss it nor reach the shortcuts behind it.
///
/// The page passes the search box it owns: the home page's sits in the split
/// view, an entry page's in its title bar. Only the page on top handles the
/// key, so a pushed entry page is never steered by the home page below it.
class SearchEscapeCloser extends ConsumerStatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  final SearchController? controller;

  const SearchEscapeCloser({
    super.key,
    required this.child,
    this.focusNode,
    this.controller,
  });

  @override
  ConsumerState<SearchEscapeCloser> createState() => _SearchEscapeCloserState();
}

class _SearchEscapeCloserState extends ConsumerState<SearchEscapeCloser> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return false;
    }
    final homeModel = ref.read(homeModelProvider);
    final controller = widget.controller ?? homeModel.searchController;
    final node = widget.focusNode ?? homeModel.searchBarFocusNode;
    final activeController = activeSearchController;
    if (activeController != null &&
        activeController.isAttached &&
        activeController.isOpen) {
      activeController.closeView(null);
      return true;
    }
    if (controller.isAttached && controller.isOpen) {
      controller.closeView(null);
      return true;
    }
    // The text field swallows Escape (DoNothingAndStopPropagation), so the
    // press has to be handled here rather than in CallbackShortcuts. The
    // focus may also have moved to the app bar, so do not require it on the
    // search box.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    final focused = activeSearchFocusNode;
    talker.info(
      "esc handler: focused=${focused?.hasFocus} dict=$activeEntryDictId",
    );
    if (focused != null && focused.hasFocus) {
      focused.unfocus();
      focusActiveEntrySoon();
    } else {
      _focusNodeAndSelectAll(node);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

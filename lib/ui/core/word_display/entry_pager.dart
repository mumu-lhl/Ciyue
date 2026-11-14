import "dart:convert";

import "package:ciyue/repositories/settings.dart";
import "package:flutter/foundation.dart";
import "package:flutter/widgets.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";

/// Where the entry on screen currently sits between its start and its end.
///
/// The paging buttons grey themselves out from this: paging up at the start
/// or down at the end would do nothing but repaint the panel.
@immutable
class PageBounds {
  final bool atStart;
  final bool atEnd;

  const PageBounds({required this.atStart, required this.atEnd});

  /// Nothing is known yet, so both directions are offered.
  static const unknown = PageBounds(atStart: false, atEnd: false);

  @override
  bool operator ==(Object other) =>
      other is PageBounds && other.atStart == atStart && other.atEnd == atEnd;

  @override
  int get hashCode => Object.hash(atStart, atEnd);

  @override
  String toString() => "PageBounds(atStart: $atStart, atEnd: $atEnd)";
}

/// Pages the entry on screen a screen at a time.
///
/// The tab layout scrolls inside a WebView, which Dart cannot read or move,
/// while the expansion layout scrolls a Flutter [ScrollController]. Both
/// hide that difference behind this interface so the keys and the buttons
/// only ever call [pageActiveEntry].
abstract interface class EntryPager {
  /// Pages by [screens] screens (negative goes up). Returns whether the page
  /// actually moved, so an attempt at the start or the end is not reported as
  /// a handled key.
  Future<bool> pageBy(int screens);

  /// The boundary state the buttons subscribe to.
  ValueListenable<PageBounds> get bounds;
}

/// One registered pager, in the shape [entryFocusTargets] already uses: the
/// owner identifies it, `dictId` and `isCurrent` pick the one on screen.
typedef EntryPagerTarget = ({
  int Function() dictId,
  bool Function() isCurrent,
  EntryPager pager,
});

final Map<Object, EntryPagerTarget> _entryPagers = {};

/// The pager of the expansion layout, which has no per-dictionary WebView.
EntryPager? _expansionPager;

/// The dictionary the tab layout is showing, if any.
int? _activeDictId;

/// The pager the keys and the buttons should talk to. Null when no entry is
/// on screen, which is what hides the buttons.
final ValueNotifier<EntryPager?> activeEntryPager = ValueNotifier<EntryPager?>(
  null,
);

void registerEntryPager(
  Object owner, {
  required int Function() dictId,
  required bool Function() isCurrent,
  required EntryPager pager,
}) {
  _entryPagers[owner] = (dictId: dictId, isCurrent: isCurrent, pager: pager);
  _recomputeActivePager();
}

void unregisterEntryPager(Object owner) {
  if (_entryPagers.remove(owner) != null) {
    _recomputeActivePager();
  }
}

/// Registers (or clears, with null) the expansion layout's own pager.
void setExpansionEntryPager(EntryPager? pager) {
  _expansionPager = pager;
  _recomputeActivePager();
}

/// Clears the expansion pager only if it is still [pager].
///
/// Two entry pages can overlap while one is being replaced; the one that is
/// going away must not clear the pager of the one that is taking over.
void clearExpansionEntryPager(EntryPager pager) {
  if (!identical(_expansionPager, pager)) return;
  setExpansionEntryPager(null);
}

/// Tells the registry which dictionary the tab layout is showing.
void setActiveEntryDict(int? dictId) {
  if (_activeDictId == dictId) return;
  _activeDictId = dictId;
  _recomputeActivePager();
}

void _recomputeActivePager() {
  final dictId = _activeDictId;
  EntryPager? found;
  if (dictId != null) {
    final onScreen = <EntryPager>[];
    final onDict = <EntryPager>[];
    for (final target in _entryPagers.values) {
      if (target.dictId() != dictId) continue;
      onDict.add(target.pager);
      if (target.isCurrent()) onScreen.add(target.pager);
    }
    // The neighbouring dictionary tabs stay alive, so a pager that belongs to
    // a route that is no longer on top is only a fallback.
    if (onScreen.isNotEmpty) {
      found = onScreen.last;
    } else if (onDict.isNotEmpty) {
      found = onDict.last;
    }
  }
  found ??= _expansionPager;
  if (!identical(activeEntryPager.value, found)) {
    activeEntryPager.value = found;
  }
}

/// The single entry point for the keys, the hardware buttons and the toolbar.
///
/// Returns whether anything moved: at the start or the end of an entry this
/// is false, and the caller stays quiet instead of forcing a repaint.
Future<bool> pageActiveEntry(int screens) async {
  final pager = activeEntryPager.value;
  if (pager == null) return false;
  return pager.pageBy(screens);
}

/// Pages an entry that scrolls in Flutter (the expansion layout).
class ScrollControllerEntryPager implements EntryPager {
  final ScrollController controller;
  final ValueNotifier<PageBounds> _bounds = ValueNotifier(PageBounds.unknown);

  ScrollControllerEntryPager(this.controller) {
    controller.addListener(_updateBounds);
    _updateBounds();
  }

  @override
  ValueListenable<PageBounds> get bounds => _bounds;

  @override
  Future<bool> pageBy(int screens) async {
    if (!controller.hasClients) return false;
    final position = controller.position;
    final step = position.viewportDimension * 0.9;
    final target = (position.pixels + step * screens).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 1) {
      _updateBounds();
      return false;
    }
    if (settings.eInkMode) {
      controller.jumpTo(target);
    } else {
      await controller.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    _updateBounds();
    return true;
  }

  void _updateBounds() {
    if (!controller.hasClients) {
      _bounds.value = PageBounds.unknown;
      return;
    }
    final position = controller.position;
    _bounds.value = PageBounds(
      atStart: position.pixels <= position.minScrollExtent + 1,
      atEnd: position.pixels >= position.maxScrollExtent - 1,
    );
  }

  void dispose() {
    controller.removeListener(_updateBounds);
    _bounds.dispose();
  }
}

/// Pages an entry rendered inside a WebView (the tab layout).
///
/// The scroll position lives in the page, so both directions and the
/// boundary state come from `pagingScript`, which is injected into every
/// entry and stays inert until the e-ink mode is switched on.
class WebViewEntryPager implements EntryPager {
  /// The controller is looked up on every call: it is null until the platform
  /// view is created and is replaced when the WebView is rebuilt.
  final InAppWebViewController? Function() controller;
  final ValueNotifier<PageBounds> _bounds = ValueNotifier(PageBounds.unknown);

  WebViewEntryPager(this.controller);

  @override
  ValueListenable<PageBounds> get bounds => _bounds;

  @override
  Future<bool> pageBy(int screens) async {
    final webView = controller();
    if (webView == null) return false;
    try {
      final raw = await webView.evaluateJavascript(
        source: "window.ciyuePageBy ? window.ciyuePageBy($screens) : ''",
      );
      return _decodePayload(raw)?["moved"] == true;
    } catch (error) {
      debugPrint("WebView paging failed: $error");
      return false;
    }
  }

  /// Feeds the state the page reported through the `ciyuePageState` handler.
  void updateFromPayload(String payload) {
    final decoded = _decodePayload(payload);
    if (decoded == null) return;
    _bounds.value = PageBounds(
      atStart: decoded["atStart"] == true,
      atEnd: decoded["atEnd"] == true,
    );
  }

  /// Pushes the current mode into the page and asks for its boundary state.
  ///
  /// Runs when the document finishes loading and whenever the setting
  /// changes, so an entry that is already open follows the switch without
  /// being rebuilt.
  Future<void> syncPagingSetting() async {
    final webView = controller();
    if (webView == null) return;
    final enabled = settings.eInkMode;
    // The state is only asked for when the buttons exist: with the mode off
    // nothing subscribes to it, and every entry would pay for the message.
    final source = enabled
        ? "window.ciyueSetPaging && window.ciyueSetPaging(true);"
              "window.ciyueReportPageState && window.ciyueReportPageState();"
        : "window.ciyueSetPaging && window.ciyueSetPaging(false);";
    try {
      await webView.evaluateJavascript(source: source);
    } catch (error) {
      debugPrint("Failed to apply the paging mode: $error");
    }
  }

  void dispose() {
    _bounds.dispose();
  }

  static Map<String, dynamic>? _decodePayload(Object? raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is! String || raw.isEmpty || raw == "null") return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      // The engine returned something that is not our payload; treat it as
      // "nothing moved" instead of failing the key press.
    }
    return null;
  }
}

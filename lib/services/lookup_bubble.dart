// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: implementation_imports
// ignore_for_file: prefer_initializing_formals

import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/lookup_exclusion.dart";
import "package:ciyue/services/lookup_popup.dart";
import "package:ciyue/services/selection_text_provider.dart";
import "package:ciyue/services/selection_watcher.dart";
import "package:flutter/src/widgets/_window.dart";
import "package:material_ui/material_ui.dart";

/// Shows the desktop lookup bubble (issue #909): a small floating button
/// that appears near the cursor after the user selects text in another app.
/// Tapping it opens the lookup popup for the selected text.
///
/// The bubble only ever appears in response to a selection event the user
/// made — the service subscribes to a [SelectionWatcher] and never polls.
/// It never throws: every failure is logged and reported as "no bubble".
class LookupBubbleService {
  LookupBubbleService({
    bool enabled = false,
    String trigger = "selection",
    String modifier = "control",
    List<String> excludedApps = const [],
    SelectionWatcher? watcher,
    FocusedAppResolver? focusedAppResolver,
    Future<String?> Function()? acquireText,
    Future<void> Function(String text)? showLookup,
    LookupBubbleWindowBackend? bubbleBackend,
    bool Function(String? appId)? isOwnApp,
    bool Function(String? appId, List<String> patterns)? isExcluded,
    Future<bool> Function(String modifier)? isModifierHeld,
    Future<bool> Function()? isDoubleClickSelection,
    Duration bubbleDwell = const Duration(seconds: 30),
  }) : _enabled = enabled,
       _trigger = trigger,
       _modifier = modifier,
       _excludedApps = excludedApps,
       _watcher = watcher,
       _focusedAppResolver = focusedAppResolver,
       _acquireText = acquireText ?? SelectionTextProviders.acquire,
       _showLookup = showLookup ?? LookupPopupService.instance.showLookup,
       _bubbleBackend = bubbleBackend ?? _defaultBubbleBackend(),
       _isOwnApp = isOwnApp ?? LookupExclusionService.isOwnApp,
       _isExcluded = isExcluded ?? LookupExclusionService.isExcluded,
       _isModifierHeld = isModifierHeld,
       _isDoubleClickSelection = isDoubleClickSelection,
       _bubbleDwell = bubbleDwell;

  /// The process-wide bubble service: a single instance for the life of
  /// the process. It is deliberately never replaced: the bubble host
  /// captures this instance when it is constructed, so swapping it out
  /// (as a `configure` that installs a new service would) leaves the host
  /// listening to a dead service whose [currentText] never changes — the
  /// native bubble window is still created, but no content is ever mounted
  /// into it and it renders black. Preference changes go through
  /// [reconfigure] instead, which updates this instance in place.
  static final LookupBubbleService instance = LookupBubbleService();

  /// Updates this service's configuration in place and restarts it, so the
  /// host never goes stale. Stops the current watcher first (releasing
  /// its subscription), then applies the new settings and starts again
  /// when enabled. A disabled bubble leaves the service stopped with no
  /// watcher behind.
  Future<void> reconfigure({
    required bool enabled,
    required String trigger,
    required String modifier,
    required List<String> excludedApps,
    required SelectionWatcher? watcher,
    required FocusedAppResolver? focusedAppResolver,
    required Future<bool> Function(String modifier)? isModifierHeld,
  }) async {
    await stop();
    _enabled = enabled;
    _trigger = trigger;
    _modifier = modifier;
    _excludedApps = excludedApps;
    _watcher = watcher;
    _focusedAppResolver = focusedAppResolver;
    _isModifierHeld = isModifierHeld;
    if (_enabled) await start();
  }

  bool _enabled;

  /// When to show the bubble: "selection" (any selection), "modifier"
  /// (only while the configured modifier key is held during the selection)
  /// or "doubleClick" (only for selections made by double-clicking, once a
  /// watcher reports them — see [_isDoubleClickSelection]).
  String _trigger;

  /// The modifier key for the "modifier" trigger: "control", "alt" or
  /// "shift".
  String _modifier;

  /// How long the bubble stays up without interaction before hiding
  /// itself: with no click-elsewhere or focus signal on the bubble window,
  /// a dwell timeout is what keeps it from lingering forever.
  final Duration _bubbleDwell;

  /// Application-id patterns the bubble never appears for.
  List<String> _excludedApps;

  SelectionWatcher? _watcher;
  FocusedAppResolver? _focusedAppResolver;
  final Future<String?> Function() _acquireText;
  final Future<void> Function(String text) _showLookup;
  final LookupBubbleWindowBackend _bubbleBackend;
  final bool Function(String? appId) _isOwnApp;
  final bool Function(String? appId, List<String> patterns) _isExcluded;

  /// Reports whether [modifier] is currently held. Lane A's X11 helper
  /// supplies this; on any other platform there is none, so a "modifier"
  /// trigger never fires there.
  Future<bool> Function(String modifier)? _isModifierHeld;

  /// Reports whether the selection behind the current event came from a
  /// double-click. No watcher reports clicks today — XFixes sees only
  /// selection-owner changes and AT-SPI2 only text-selection changes —
  /// so this is null until a watcher learns to observe them, and a
  /// "doubleClick" trigger never fires until then.
  final Future<bool> Function()? _isDoubleClickSelection;

  /// Serializes selection-event handling: the handler awaits the focused
  /// app, the modifier state and the text, so without this a slow event
  /// could show its bubble after a newer event already hid it, or a
  /// later-finishing event could overwrite a newer selection's text.
  Future<void> _eventQueue = Future<void>.value();

  /// Hides the bubble [bubbleDwell] after it was shown, if nothing
  /// dismissed it first. Restarted on every show.
  Timer? _dwellTimer;

  /// The text the bubble is currently shown for, or null when hidden. The
  /// bubble host listens to this and mounts/unmounts the bubble view.
  final ValueNotifier<String?> currentText = ValueNotifier<String?>(null);

  bool _started = false;
  StreamSubscription<bool>? _subscription;

  /// Whether the bubble is currently shown.
  bool get isVisible => currentText.value != null;

  /// Whether [start] has taken effect.
  bool get isRunning => _started;

  /// The backend the host renders into. Exposed so the host and the service
  /// share the single bubble controller.
  LookupBubbleWindowBackend get bubbleBackend => _bubbleBackend;

  /// The popup window's backend doubles as the bubble backend; when it
  /// cannot (a test double, say), the bubble stays unavailable rather than
  /// crashing startup.
  static LookupBubbleWindowBackend _defaultBubbleBackend() {
    return switch (LookupPopupService.instance.windowBackend) {
      LookupBubbleWindowBackend bubbleBackend => bubbleBackend,
      _ => const _UnavailableBubbleWindowBackend(),
    };
  }

  /// Subscribes to the watcher and starts it. A no-op when disabled, when
  /// no watcher was wired, or when the watcher is unavailable in this
  /// process. Never throws.
  Future<void> start() async {
    if (_started) return;
    if (!_enabled) return;
    final watcher = _watcher;
    if (watcher == null || !watcher.isAvailable) return;
    try {
      _subscription = watcher.onSelectionChanged.listen(
        _onSelectionChanged,
        onError: (Object error, StackTrace stackTrace) {
          talker.error(
            "Lookup bubble selection watcher failed",
            error,
            stackTrace,
          );
        },
      );
      await watcher.start();
      _started = true;
    } catch (error, stackTrace) {
      talker.error("Failed to start the lookup bubble", error, stackTrace);
      await _subscription?.cancel();
      _subscription = null;
    }
  }

  /// Hides the bubble and stops the watcher. Idempotent, never throws.
  Future<void> stop() async {
    hide();
    if (!_started) return;
    _started = false;
    try {
      await _subscription?.cancel();
      await _watcher?.stop();
    } catch (error, stackTrace) {
      talker.error("Failed to stop the lookup bubble", error, stackTrace);
    } finally {
      _subscription = null;
    }
  }

  /// Hides the bubble window and clears the text. Idempotent, never throws.
  void hide() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    if (currentText.value != null) currentText.value = null;
    try {
      unawaited(
        _bubbleBackend.hideBubble().then<void>(
          (_) {},
          onError: (Object error) {
            talker.warning("Failed to hide the lookup bubble: $error");
          },
        ),
      );
    } catch (error) {
      talker.warning("Failed to hide the lookup bubble: $error");
    }
  }

  /// Opens the lookup popup for the bubble's text and hides the bubble.
  /// A no-op when the bubble is not shown. Never throws.
  Future<void> openLookup() async {
    final text = currentText.value;
    if (text == null || text.isEmpty) return;
    try {
      // Show the popup before hiding the bubble: dismissing the bubble
      // first unmounts its view, and creating the popup's view right
      // after the teardown crashes the app under Xvfb + llvmpipe (GLX
      // BadAccess while the GL context changes hands). With the bubble
      // still up, the popup's view is created alongside a live view —
      // the same coexistence the main window and popup already rely on.
      await _showLookup(text);
    } catch (error, stackTrace) {
      talker.error("Failed to open the lookup popup", error, stackTrace);
    }
    // Only dismiss the bubble when it still shows the text this tap was
    // for: a newer selection may have arrived while the popup was
    // opening, and hiding unconditionally would clear its text.
    if (currentText.value == text) hide();
  }

  /// Queues a selection event behind any event still being handled, so
  /// events are applied strictly in arrival order (see [_eventQueue]).
  void _onSelectionChanged(bool appeared) {
    _eventQueue = _eventQueue.then((_) => _handleSelectionChanged(appeared));
  }

  Future<void> _handleSelectionChanged(bool appeared) async {
    try {
      if (!appeared) {
        hide();
        return;
      }
      if (_trigger == "modifier") {
        // No modifier-state helper on this platform: treat the modifier
        // as not held and ignore the selection. The bubble from a previous
        // selection is stale now, so hide it.
        final held = await _isModifierHeld?.call(_modifier) ?? false;
        if (!held) {
          hide();
          return;
        }
      }
      if (_trigger == "doubleClick") {
        // No watcher reports clicks yet, so without a helper this
        // trigger never fires rather than firing on every selection.
        final doubleClick = await _isDoubleClickSelection?.call() ?? false;
        if (!doubleClick) {
          hide();
          return;
        }
      }
      final appId = await _resolveFocusedApp();
      // Fail closed on an unknown app: the resolver is null on Wayland
      // and may fail anywhere, and showing then would pop the bubble
      // inside Ciyue itself and leave the exclusion list — password
      // managers included — unenforced. An unknown app is not excluded
      // (see [LookupExclusionService.isExcluded]); it is unprovable, so
      // the bubble stays down.
      if (appId == null ||
          _isOwnApp(appId) ||
          _isExcluded(appId, _excludedApps)) {
        hide();
        return;
      }
      final text = (await _acquireText())?.trim();
      if (text == null || text.isEmpty) {
        hide();
        return;
      }
      await _showBubble(text);
    } catch (error, stackTrace) {
      talker.error(
        "Failed to handle a selection change for the lookup bubble",
        error,
        stackTrace,
      );
    }
  }

  Future<String?> _resolveFocusedApp() async {
    final resolver = _focusedAppResolver;
    if (resolver == null) return null;
    try {
      return await resolver.getFocusedAppId();
    } catch (error, stackTrace) {
      talker.warning(
        "Failed to resolve the focused app for the lookup bubble: $error",
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> _showBubble(String text) async {
    try {
      await _bubbleBackend.createBubble();
      if (!_bubbleBackend.isBubbleCreated) return;
      // Position by the window's realized size when known: the platform
      // may realize it larger than the preferred 48x48, and clamping by
      // 48 would put the real button ~108px from the cursor and let the
      // window overshoot the work area near edges.
      final size =
          await _bubbleBackend.bubbleWindowSize() ??
          LookupPopupService.bubbleSize;
      final position = await _positionNearCursor(size);
      if (position != null) await _bubbleBackend.setBubblePosition(position);
      currentText.value = text;
      await _bubbleBackend.showBubble();
      // The size read above may predate realization (the native handle is
      // null until the window is mapped), so re-read it now that the
      // window is shown and re-position when the realized size differs.
      final realizedSize = await _bubbleBackend.bubbleWindowSize();
      if (realizedSize != null && realizedSize != size) {
        final realizedPosition = await _positionNearCursor(realizedSize);
        if (realizedPosition != null) {
          await _bubbleBackend.setBubblePosition(realizedPosition);
        }
      }
      _dwellTimer?.cancel();
      _dwellTimer = Timer(_bubbleDwell, hide);
    } catch (error, stackTrace) {
      talker.error("Failed to show the lookup bubble", error, stackTrace);
      currentText.value = null;
    }
  }

  /// The bubble position: below-right of the cursor, clamped inside the
  /// work area of the display holding the cursor (primary when that is
  /// unknown); centred on it when the cursor is unknown; null when even
  /// the display is unknown (platform default then applies).
  Future<Offset?> _positionNearCursor(Size windowSize) async {
    final workArea =
        await _bubbleBackend.workAreaAtCursor() ??
        await _bubbleBackend.primaryWorkArea();
    if (workArea == null) return null;
    final cursor = await _bubbleBackend.cursorPosition();
    if (cursor == null) {
      return LookupPopupService.centerPopupPosition(
        popupSize: windowSize,
        workArea: workArea,
      );
    }
    return LookupPopupService.clampPopupPosition(
      cursor: cursor,
      popupSize: windowSize,
      workArea: workArea,
    );
  }
}

/// Stand-in backend for a process where the popup backend cannot serve as a
/// bubble backend: the bubble stays unavailable and every call is a no-op.
class _UnavailableBubbleWindowBackend implements LookupBubbleWindowBackend {
  const _UnavailableBubbleWindowBackend();

  @override
  bool get isAvailable => false;

  @override
  bool get isBubbleCreated => false;

  @override
  WindowController? get bubbleController => null;

  @override
  Future<void> createBubble() async {}

  @override
  Future<void> showBubble() async {}

  @override
  Future<void> hideBubble() async {}

  @override
  Future<void> setBubblePosition(Offset position) async {}

  @override
  Future<Offset?> cursorPosition() async => null;

  @override
  Future<Rect?> primaryWorkArea() async => null;

  @override
  Future<Rect?> workAreaAtCursor() async => null;

  @override
  Future<Size?> bubbleWindowSize() async => null;
}

// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: implementation_imports

import "dart:async";
import "dart:math" as math;

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/services/lookup_mode.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/selection_text_provider.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:flutter/src/foundation/_features.dart";
import "package:flutter/src/widgets/_window.dart";
import "package:material_ui/material_ui.dart";
import "package:nativeapi/nativeapi.dart" as nativeapi;
import "package:window_manager/windowing.dart";

/// A lookup to show in the desktop popup window: the text plus how the
/// popup page should handle it. [sequence] is a monotonically increasing
/// generation assigned by the service: two requests for the same text must
/// still notify listeners, and [ValueNotifier] only notifies when the new
/// value differs under ==.
class LookupPopupRequest {
  const LookupPopupRequest({
    required this.text,
    required this.mode,
    this.sequence = 0,
  });

  final String text;
  final LookupMode mode;
  final int sequence;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LookupPopupRequest &&
          other.text == text &&
          other.mode == mode &&
          other.sequence == sequence);

  @override
  int get hashCode => Object.hash(text, mode, sequence);
}

/// The native-window operations the popup service needs, behind an
/// interface so tests can substitute a fake: widget tests cannot create
/// native windows, and the service must never call Flutter's windowing
/// APIs directly.
abstract class LookupPopupWindowBackend {
  /// Whether a second native window can be opened at all: desktop platform
  /// with the experimental multi-window API enabled.
  bool get isAvailable;

  /// Whether the popup's native window has been created.
  bool get isCreated;

  /// The controller the host renders the popup content into, or null until
  /// [create] runs.
  WindowController? get controller;

  /// Creates the popup's native window. The controller is created once per
  /// process and reused for every lookup; it is never destroyed (see
  /// [RealLookupPopupWindowBackend]).
  Future<void> create();

  /// Shows the popup window without taking keyboard focus from the app the
  /// user was working in. Returns whether the window actually came up:
  /// false when there is no native window or showing it failed, so the
  /// caller never reports a visible popup that never appeared.
  Future<bool> show();

  /// Hides the popup window. Never throws.
  Future<void> hide();

  /// Moves the popup window's top-left corner to [position].
  Future<void> setPosition(Offset position);

  /// Whether the popup window has no native frame.
  Future<void> setFrameless(bool frameless);

  /// Whether the popup window stays above other windows.
  Future<void> setAlwaysOnTop(bool alwaysOnTop);

  /// The global mouse position, or null when it cannot be read.
  Future<Offset?> cursorPosition();

  /// The usable rect of the primary display, or null when it cannot be read.
  Future<Rect?> primaryWorkArea();

  /// The usable rect of the display holding the cursor, or null when it
  /// cannot be determined: the caller falls back to [primaryWorkArea].
  /// A secondary-monitor cursor must not be clamped back to the primary
  /// screen.
  Future<Rect?> workAreaAtCursor();

  /// Called when the popup window loses focus after having had it. The
  /// service hides the popup from here; the backend only tracks the
  /// focus/blur pair and never hides anything itself.
  set onFocusLost(void Function()? handler);
}

/// The native-window operations the lookup bubble needs, on the same
/// backend object that owns the popup window: a popup controller beside
/// the popup's, behind the same interface shape so tests can substitute a
/// fake. The methods are bubble-named because the backend implements both
/// this and [LookupPopupWindowBackend], whose `show`/`hide` already belong
/// to the popup window.
abstract class LookupBubbleWindowBackend {
  /// Whether a second native window can be opened at all: desktop platform
  /// with the experimental multi-window API enabled.
  bool get isAvailable;

  /// Whether the bubble's native window has been created.
  bool get isBubbleCreated;

  /// The controller the host renders the bubble content into, or null until
  /// [createBubble] runs.
  WindowController? get bubbleController;

  /// Creates the bubble's native window. The controller is created once per
  /// process and reused for every selection; it is never destroyed (same
  /// reason as the popup's: destroying a second window killed the whole app
  /// under Xvfb + software GL).
  Future<void> createBubble();

  /// Shows the bubble window without taking keyboard focus.
  Future<void> showBubble();

  /// Hides the bubble window. Never throws.
  Future<void> hideBubble();

  /// Moves the bubble window's top-left corner to [position].
  Future<void> setBubblePosition(Offset position);

  /// The global mouse position, or null when it cannot be read.
  Future<Offset?> cursorPosition();

  /// The usable rect of the primary display, or null when it cannot be read.
  Future<Rect?> primaryWorkArea();

  /// The usable rect of the display holding the cursor, or null when it
  /// cannot be determined: the caller falls back to [primaryWorkArea].
  Future<Rect?> workAreaAtCursor();

  /// The bubble window's actual size once realized, or null when the
  /// window does not exist yet: the platform may realize it larger than
  /// the preferred 48x48, and positioning must use the real size.
  Future<Size?> bubbleWindowSize();
}

/// The real [LookupPopupWindowBackend]: one [WindowController] per process,
/// driven through nativeapi for positioning and visibility. It also serves
/// as the [LookupBubbleWindowBackend] with a second, lazily-created
/// controller for the bubble window.
class RealLookupPopupWindowBackend
    implements LookupPopupWindowBackend, LookupBubbleWindowBackend {
  WindowController? _controller;
  WindowController? _bubbleController;

  /// The focus-loss listener on the popup's native window, or null until
  /// [create] registers it. The backend lives for the process, so the
  /// listener is intentionally never removed in production; [dispose]
  /// removes it for completeness.
  nativeapi.ListenerId? _focusListenerId;

  /// Whether the popup window has held the focus since it was last shown:
  /// a blur that never had a focus must not hide anything.
  bool _popupHadFocus = false;

  void Function()? _onFocusLost;

  @override
  set onFocusLost(void Function()? handler) => _onFocusLost = handler;

  @override
  bool get isAvailable => isDesktop() && isWindowingEnabled;

  @override
  bool get isCreated => _controller != null;

  @override
  WindowController? get controller => _controller;

  nativeapi.Window? get _nativeWindow {
    final controller = _controller;
    if (controller == null) return null;
    try {
      return nativeWindowOf(controller);
    } catch (error) {
      talker.warning("Failed to resolve the popup native window: $error");
      return null;
    }
  }

  nativeapi.Window? get _bubbleNativeWindow {
    final controller = _bubbleController;
    if (controller == null) return null;
    try {
      return nativeWindowOf(controller);
    } catch (error) {
      talker.warning("Failed to resolve the bubble native window: $error");
      return null;
    }
  }

  /// Removes the popup's focus-loss listener, if one was registered.
  void dispose() {
    final listenerId = _focusListenerId;
    if (listenerId != null) {
      try {
        nativeapi.WindowManager.instance.removeListener(listenerId);
      } catch (error) {
        talker.warning(
          "Failed to remove the lookup popup focus listener: $error",
        );
      }
    }
    _focusListenerId = null;
  }

  @override
  Future<void> create() async {
    if (_controller != null) return;
    if (!isAvailable) return;
    try {
      // The size is explicit: shrinkWrap does not size the window (GTK
      // falls back to 200x200), so the controller carries the popup size.
      _controller = WindowController(
        size: LookupPopupService.popupSize,
        title: "Ciyue",
      );
    } catch (error, stackTrace) {
      talker.error(
        "Failed to create the lookup popup window",
        error,
        stackTrace,
      );
      _controller = null;
      return;
    }
    // Positioning and always-on-top are compositor-controlled on Wayland
    // and may silently no-op there; a failure here must not lose the lookup.
    try {
      final nativeWindow = _nativeWindow;
      if (nativeWindow != null) nativeWindow.isAlwaysOnTop = true;
    } catch (error) {
      talker.warning("Failed to set the lookup popup always on top: $error");
    }
    _registerFocusLossListener();
  }

  /// Listens for the popup window losing focus, once per process. Only a
  /// blur that follows a focus since the window was created dismisses the
  /// popup: the popup is shown inactive and may never gain focus, so an
  /// unguarded blur would hide a popup the user never interacted with.
  ///
  /// The subscription lives on the [nativeapi.WindowManager], not on the
  /// popup's own window: the native side dispatches focus events through
  /// the manager, and a listener on an adopted window object never sees
  /// them (verified in a real window: the per-window listener stayed
  /// silent through a real focus/blur cycle). Events are filtered by the
  /// popup's window id.
  ///
  /// The native window is not resolvable right after the controller is
  /// constructed — its handle is null until the window is realized — so
  /// this is also (re-)attempted from [show], when the window exists.
  /// A null window here is warned about, never silently skipped: the
  /// create-time call used to return quietly, which left the popup with
  /// no focus listener and no always-on-top state.
  void _registerFocusLossListener() {
    if (_focusListenerId != null) return;
    final popupId = _nativeWindow?.id;
    if (popupId == null) {
      talker.warning(
        "Cannot listen for lookup popup focus loss: no native window",
      );
      return;
    }
    try {
      _focusListenerId = nativeapi.WindowManager.instance.addListener((event) {
        if (event.windowId != popupId) return;
        if (event is nativeapi.WindowFocusedEvent) {
          _popupHadFocus = true;
        } else if (event is nativeapi.WindowBlurredEvent) {
          if (_popupHadFocus) {
            _popupHadFocus = false;
            _onFocusLost?.call();
          }
        }
      });
    } catch (error, stackTrace) {
      talker.warning(
        "Failed to listen for lookup popup focus loss",
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<bool> show() async {
    final nativeWindow = _nativeWindow;
    if (nativeWindow == null) {
      talker.warning("Cannot show the lookup popup: no native window");
      return false;
    }
    // Any focus state from a previous showing is stale: a blur recorded
    // before this show must not dismiss the popup that is about to open.
    _popupHadFocus = false;
    // The window is realized by now, so the create-time native setup
    // that silently skipped on a null handle is (re-)applied here:
    // always-on-top plus the focus-loss listener. Both are idempotent.
    // They run after showInactive on purpose: the window must be mapped
    // first, or the window manager drops the keep-above request and the
    // native event subscription never sees a focus change.
    try {
      // Inactive on purpose: the hotkey fires while the user works in
      // another app, and stealing focus would move their cursor there.
      nativeWindow.showInactive();
    } catch (error, stackTrace) {
      talker.error("Failed to show the lookup popup window", error, stackTrace);
      return false;
    }
    try {
      nativeWindow.isAlwaysOnTop = true;
    } catch (error) {
      talker.warning("Failed to set the lookup popup always on top: $error");
    }
    _registerFocusLossListener();
    return true;
  }

  @override
  Future<void> hide() async {
    _popupHadFocus = false;
    try {
      _nativeWindow?.hide();
    } catch (error) {
      talker.warning("Failed to hide the lookup popup window: $error");
    }
  }

  @override
  Future<void> setPosition(Offset position) async {
    try {
      final nativeWindow = _nativeWindow;
      if (nativeWindow != null) {
        nativeWindow.position = nativeapi.Point(x: position.dx, y: position.dy);
      }
    } catch (error) {
      talker.warning("Failed to position the lookup popup window: $error");
    }
  }

  @override
  Future<void> setFrameless(bool frameless) async {
    try {
      _nativeWindow?.setFrameless(frameless);
    } catch (error) {
      talker.warning("Failed to set the lookup popup frameless: $error");
    }
  }

  @override
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {
    try {
      final nativeWindow = _nativeWindow;
      if (nativeWindow != null) nativeWindow.isAlwaysOnTop = alwaysOnTop;
    } catch (error) {
      talker.warning("Failed to set the lookup popup always on top: $error");
    }
  }

  @override
  Future<Offset?> cursorPosition() async {
    try {
      final point = nativeapi.DisplayManager.instance.getCursorPosition();
      return Offset(point.x, point.y);
    } catch (error) {
      talker.warning("Failed to read the cursor position: $error");
      return null;
    }
  }

  @override
  Future<Rect?> primaryWorkArea() async {
    try {
      final display = nativeapi.DisplayManager.instance.getPrimary();
      if (display == null) return null;
      final area = display.workArea;
      return Rect.fromLTWH(area.x, area.y, area.width, area.height);
    } catch (error) {
      talker.warning("Failed to read the primary display work area: $error");
      return null;
    }
  }

  @override
  Future<Rect?> workAreaAtCursor() async {
    try {
      final cursor = nativeapi.DisplayManager.instance.getCursorPosition();
      for (final display in nativeapi.DisplayManager.instance.getAll()) {
        final position = display.position;
        final size = display.size;
        if (cursor.x >= position.x &&
            cursor.x < position.x + size.width &&
            cursor.y >= position.y &&
            cursor.y < position.y + size.height) {
          final area = display.workArea;
          return Rect.fromLTWH(area.x, area.y, area.width, area.height);
        }
      }
    } catch (error) {
      talker.warning("Failed to read the work area at the cursor: $error");
    }
    return null;
  }

  @override
  bool get isBubbleCreated => _bubbleController != null;

  @override
  WindowController? get bubbleController => _bubbleController;

  @override
  Future<void> createBubble() async {
    if (_bubbleController != null) return;
    if (!isAvailable) return;
    try {
      // Same explicit-size reason as the popup: shrinkWrap does not size
      // the window, so the controller carries the bubble size.
      //
      // A PopupWindowController was tried first: it gives a true 48x48
      // window, but its view never gets a GL context under Xvfb +
      // llvmpipe ("Failed to setup compositor shaders, unable to make
      // OpenGL context current"), so the bubble renders solid black and
      // never receives input there. A toplevel window renders fine in
      // this setup; its size is only a preferred size the platform may
      // not honor (it comes up ~264x264 here). That oversize rect would
      // block clicks to the app underneath, so [showBubble] narrows the
      // window's input shape to the 48px circle once the window is
      // realized; where input shapes are unsupported the transparent
      // margins still swallow clicks.
      _bubbleController = WindowController(
        size: LookupPopupService.bubbleSize,
        title: "Ciyue",
      );
    } catch (error, stackTrace) {
      talker.error(
        "Failed to create the lookup bubble window",
        error,
        stackTrace,
      );
      _bubbleController = null;
      return;
    }
    try {
      final nativeWindow = _bubbleNativeWindow;
      if (nativeWindow != null) {
        nativeWindow.setFrameless(true);
        nativeWindow.isAlwaysOnTop = true;
      }
    } catch (error) {
      talker.warning("Failed to set up the lookup bubble window: $error");
    }
  }

  @override
  Future<void> showBubble() async {
    final nativeWindow = _bubbleNativeWindow;
    if (nativeWindow == null) {
      talker.warning("Cannot show the lookup bubble: no native window");
      return;
    }
    try {
      // Inactive on purpose, like the popup: the bubble must not steal
      // focus from the app the user is selecting text in.
      nativeWindow.showInactive();
    } catch (error, stackTrace) {
      talker.error(
        "Failed to show the lookup bubble window",
        error,
        stackTrace,
      );
    }
    _applyBubbleInputShape(nativeWindow);
  }

  /// Narrows the bubble window's input to the 48px button circle, centred
  /// in the window's realized size: without this, the toplevel window's
  /// oversize rect (~264x264 where the preferred 48x48 is not honored)
  /// blocks clicks to the app underneath in its transparent margins.
  /// Best-effort: where input shapes are unsupported the window keeps
  /// its full rect and the click-blocking remains.
  void _applyBubbleInputShape(nativeapi.Window nativeWindow) {
    try {
      if (!nativeapi.Window.isInputShapeSupported()) {
        talker.warning(
          "Bubble input shape unsupported: the bubble window may block "
          "clicks outside its button",
        );
        return;
      }
      final size = nativeWindow.size;
      if (size.width <= 0 || size.height <= 0) return;
      final shape = nativeapi.WindowShape.create();
      if (shape == null) return;
      try {
        final centerX = size.width / 2;
        final centerY = size.height / 2;
        final radius = LookupPopupService.bubbleSize.width / 2;
        // A circle approximated by a polygon: the shape API takes points.
        for (var i = 0; i < 32; i++) {
          final angle = i * 2 * math.pi / 32;
          shape.addPoint(
            nativeapi.Point(
              x: centerX + radius * math.cos(angle),
              y: centerY + radius * math.sin(angle),
            ),
          );
        }
        if (!nativeWindow.setInputShape(shape)) {
          talker.warning("Failed to set the bubble input shape");
        }
      } finally {
        shape.dispose();
      }
    } catch (error, stackTrace) {
      talker.warning(
        "Failed to apply the bubble input shape",
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<void> hideBubble() async {
    try {
      _bubbleNativeWindow?.hide();
    } catch (error) {
      talker.warning("Failed to hide the lookup bubble window: $error");
    }
  }

  @override
  Future<void> setBubblePosition(Offset position) async {
    try {
      final nativeWindow = _bubbleNativeWindow;
      if (nativeWindow != null) {
        nativeWindow.position = nativeapi.Point(x: position.dx, y: position.dy);
      }
    } catch (error) {
      talker.warning("Failed to position the lookup bubble window: $error");
    }
  }

  @override
  Future<Size?> bubbleWindowSize() async {
    try {
      final size = _bubbleNativeWindow?.size;
      if (size == null || size.width <= 0 || size.height <= 0) return null;
      return Size(size.width, size.height);
    } catch (error) {
      talker.warning("Failed to read the bubble window size: $error");
      return null;
    }
  }
}

/// Shows the desktop lookup popup (issue #909): a second native window near
/// the cursor with the selected text looked up or translated.
///
/// The popup window is created once and reused. Its controller is never
/// destroyed: destroying a second window killed the whole app under Xvfb +
/// software GL, so dismiss only hides the native window and clears the
/// request the host renders.
class LookupPopupService {
  LookupPopupService({
    LookupPopupWindowBackend? windowBackend,
    Future<String?> Function()? acquireSelectionText,
    void Function(String text)? fallbackNavigate,
    Future<void> Function()? onNoTextSelected,
  }) : _backend = windowBackend ?? RealLookupPopupWindowBackend(),
       _acquireSelectionText =
           acquireSelectionText ?? SelectionTextProviders.acquire,
       _fallbackNavigate = fallbackNavigate ?? navigateToProcessText,
       _onNoTextSelected = onNoTextSelected ?? _defaultNoTextToast {
    // Dismiss on focus loss, but only while visible: the backend already
    // guards on the popup having held the focus, and hide() is idempotent,
    // so a stray blur can never close something that is not open.
    _backend.onFocusLost = () {
      if (_visible) hide();
    };
  }

  static final LookupPopupService instance = LookupPopupService();

  /// The popup window size, passed explicitly to the [WindowController]:
  /// shrinkWrap does not size the window.
  static const Size popupSize = Size(440, 560);

  /// The bubble window size: a single icon button.
  static const Size bubbleSize = Size(48, 48);

  /// Where the popup's top-left corner lands relative to the cursor.
  static const Offset cursorOffset = Offset(12, 16);

  final LookupPopupWindowBackend _backend;
  final Future<String?> Function() _acquireSelectionText;
  final void Function(String text) _fallbackNavigate;
  final Future<void> Function() _onNoTextSelected;

  /// The lookup the host is currently rendering, or null when the popup is
  /// closed. The host listens to this and mounts/unmounts the popup view.
  final ValueNotifier<LookupPopupRequest?> currentRequest =
      ValueNotifier<LookupPopupRequest?>(null);

  bool _visible = false;

  /// Whether the popup window is currently shown.
  bool get isVisible => _visible;

  /// Generation of the latest show/hide: an in-flight [showLookup] whose
  /// generation is stale must not re-raise a popup a later [hide] closed.
  int _showEpoch = 0;

  /// Sequence stamped on every request so re-looking up the same text
  /// still notifies listeners (see [LookupPopupRequest.sequence]).
  int _requestSequence = 0;

  /// The backend the host renders into. Exposed so the host and the service
  /// share the single popup controller.
  LookupPopupWindowBackend get windowBackend => _backend;

  /// Shows the popup for [text], acquiring the selected text when none is
  /// given. With no text at all the user is told so and nothing opens.
  /// When a second window is unavailable the lookup falls back to the main
  /// window instead. Never throws.
  Future<void> showLookup(String? text) async {
    final epoch = ++_showEpoch;
    String? query;
    try {
      query = text?.trim();
      query ??= (await _acquireSelectionText())?.trim();
      if (epoch != _showEpoch) return;
      if (query == null || query.isEmpty) {
        await _onNoTextSelected();
        return;
      }

      final request = LookupPopupRequest(
        text: query,
        mode: decideLookupMode(query),
        sequence: ++_requestSequence,
      );

      if (!_backend.isAvailable) {
        _fallbackToMainWindow(query);
        return;
      }

      final position = await _positionNearCursor();
      if (epoch != _showEpoch) return;
      await _backend.create();
      if (epoch != _showEpoch) return;
      if (!_backend.isCreated) {
        _fallbackToMainWindow(query);
        return;
      }
      if (position != null) await _backend.setPosition(position);
      if (epoch != _showEpoch) return;
      currentRequest.value = request;
      if (!await _backend.show()) {
        hide();
        _fallbackToMainWindow(query);
        return;
      }
      if (epoch != _showEpoch) return;
      _visible = true;
    } catch (error, stackTrace) {
      talker.error("Failed to show the lookup popup", error, stackTrace);
      hide();
      // Fall back to the query already acquired inside try: with no
      // explicit text the old code fell back to nothing and the lookup
      // was silently lost.
      final fallbackQuery = query?.trim();
      if (fallbackQuery != null && fallbackQuery.isNotEmpty) {
        _fallbackToMainWindow(fallbackQuery);
      }
    }
  }

  /// Hides the popup window and clears the request. Idempotent, never throws.
  void hide() {
    _showEpoch++;
    _visible = false;
    if (currentRequest.value != null) currentRequest.value = null;
    try {
      unawaited(
        _backend.hide().then<void>(
          (_) {},
          onError: (Object error) {
            talker.warning("Failed to hide the lookup popup window: $error");
          },
        ),
      );
    } catch (error) {
      talker.warning("Failed to hide the lookup popup window: $error");
    }
  }

  /// The popup position: below-right of the cursor, clamped inside the
  /// work area of the display holding the cursor (primary when that is
  /// unknown); centred on it when the cursor is unknown; null when even
  /// the display is unknown (platform default then applies).
  Future<Offset?> _positionNearCursor() async {
    final workArea =
        await _backend.workAreaAtCursor() ?? await _backend.primaryWorkArea();
    if (workArea == null) return null;
    final cursor = await _backend.cursorPosition();
    if (cursor == null) {
      return centerPopupPosition(popupSize: popupSize, workArea: workArea);
    }
    return clampPopupPosition(
      cursor: cursor,
      popupSize: popupSize,
      workArea: workArea,
    );
  }

  void _fallbackToMainWindow(String text) {
    try {
      _fallbackNavigate(text);
    } catch (error, stackTrace) {
      talker.error(
        "Failed to fall back to the main window lookup",
        error,
        stackTrace,
      );
    }
  }

  /// Clamps the cursor-relative popup rect inside [workArea]. When the work
  /// area is smaller than the popup in a dimension, the popup starts at the
  /// work area's edge in that dimension.
  static Offset clampPopupPosition({
    required Offset cursor,
    required Size popupSize,
    required Rect workArea,
  }) {
    final topLeft = cursor + cursorOffset;
    final maxX = workArea.right - popupSize.width;
    final maxY = workArea.bottom - popupSize.height;
    final x = maxX <= workArea.left
        ? workArea.left
        : topLeft.dx.clamp(workArea.left, maxX).toDouble();
    final y = maxY <= workArea.top
        ? workArea.top
        : topLeft.dy.clamp(workArea.top, maxY).toDouble();
    return Offset(x, y);
  }

  /// Centres the popup rect inside [workArea].
  static Offset centerPopupPosition({
    required Size popupSize,
    required Rect workArea,
  }) {
    return Offset(
      workArea.left + (workArea.width - popupSize.width) / 2,
      workArea.top + (workArea.height - popupSize.height) / 2,
    );
  }

  static Future<void> _defaultNoTextToast() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    await ToastService.show(
      AppLocalizations.of(context)!.lookupPopupNoTextSelected,
      context,
      type: ToastType.info,
    );
  }
}

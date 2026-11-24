import "dart:async";
import "dart:ffi";
import "dart:isolate";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/desktop_selection_x11.dart";
import "package:ciyue/services/selection_watcher.dart";

typedef _XFixesQueryExtensionNative = Int32 Function(
  Pointer<Void>,
  Pointer<Int32>,
  Pointer<Int32>,
);
typedef _XFixesQueryExtensionDart = int Function(
  Pointer<Void>,
  Pointer<Int32>,
  Pointer<Int32>,
);

typedef _XFixesSelectSelectionInputNative = Void Function(
  Pointer<Void>,
  Uint64,
  Uint64,
  Uint64,
);
typedef _XFixesSelectSelectionInputDart = void Function(
  Pointer<Void>,
  int,
  int,
  int,
);

// XFixesSetSelectionOwnerNotifyMask (xfixeswire.h): the only event this
// watcher subscribes to — a new selection owner, or None when cleared.
const _selectionOwnerNotifyMask = 1;

// XFixesSelectionNotifyEvent subtype for an owner change (xfixeswire.h).
const _setSelectionOwnerNotify = 0;

/// Watches the X11 PRIMARY selection through XFixes owner-change events.
///
/// The event loop runs in a spawned isolate and reports `true` when a
/// selection owner appears and `false` when the owner becomes None. The
/// event stream is the whole mechanism for selection changes — there is
/// no polling for those — but the loop itself polls `XPending` so it can
/// notice a stop request and exit on its own: a killed isolate never
/// runs its `finally` block, which would leak its display connection and
/// its 1x1 event window on every restart.
///
/// Two limits of the protocol, both verified by probe (2026-11-23, Xvfb,
/// XFixes 6.0):
/// - An owner change fires when the selection moves to a different owner,
///   not when the user re-selects different text inside the same app: the
///   owner window is unchanged, so no event is generated and the bubble
///   does not refresh on same-app re-selection. AT-SPI2 (Lane B) covers
///   that case.
/// - When the owner process dies or its window is destroyed without
///   explicitly clearing the selection, this X server sends no event at
///   all, so a stale `true` stands until another owner takes over. An
///   explicit clear (what GTK does when the user deselects) does arrive
///   as an owner-None event.
class XFixesSelectionWatcher implements SelectionWatcher {
  XFixesSelectionWatcher();

  /// Whether the watcher can run in this process: libX11 and libXfixes
  /// open, the XFixes extension answers, and a display connects. Cached;
  /// never throws.
  static bool get _checkAvailable {
    final cached = _available;
    if (cached != null) return cached;
    try {
      final bindings = X11Bindings.instance;
      if (bindings == null) {
        _available = false;
        return false;
      }
      final xfixes = DynamicLibrary.open("libXfixes.so.3");
      final queryExtension = xfixes
          .lookupFunction<
            _XFixesQueryExtensionNative,
            _XFixesQueryExtensionDart
          >("XFixesQueryExtension");
      xfixes.lookupFunction<
        _XFixesSelectSelectionInputNative,
        _XFixesSelectSelectionInputDart
      >("XFixesSelectSelectionInput");
      final display = bindings.openDisplay(nullptr);
      if (display == nullptr) {
        _available = false;
        return false;
      }
      try {
        final eventBase = bindings.allocInt32();
        final errorBase = bindings.allocInt32();
        try {
          if (queryExtension(display, eventBase, errorBase) == 0) {
            _available = false;
            return false;
          }
        } finally {
          bindings.freePointer(eventBase);
          bindings.freePointer(errorBase);
        }
      } finally {
        bindings.closeDisplay(display);
      }
      _available = true;
      return true;
    } catch (error, stackTrace) {
      talker.warning(
        "XFixes selection watcher is unavailable",
        error,
        stackTrace,
      );
      _available = false;
      return false;
    }
  }

  static bool? _available;

  StreamController<bool> _controller = StreamController<bool>.broadcast();

  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _subscription;

  /// The isolate's control port: sending anything on it asks the isolate
  /// to exit on its own, so its `finally` block destroys its window and
  /// closes its display connection.
  SendPort? _isolateControl;

  /// Notified when the isolate exits; [stop] waits on it before giving
  /// up and killing the isolate.
  ReceivePort? _exitPort;

  @override
  bool get isAvailable => _checkAvailable;

  @override
  Stream<bool> get onSelectionChanged => _controller.stream;

  @override
  Future<void> start() async {
    if (_isolate != null) return;
    if (!isAvailable) return;
    if (_controller.isClosed) {
      _controller = StreamController<bool>.broadcast();
    }
    try {
      final receivePort = ReceivePort();
      _receivePort = receivePort;
      _subscription = receivePort.listen((message) {
        if (message is bool) {
          // A queued event may arrive after stop() closed the stream.
          if (!_controller.isClosed) _controller.add(message);
        } else if (message is SendPort) {
          _isolateControl = message;
        }
      });
      final exitPort = ReceivePort();
      _exitPort = exitPort;
      _isolate = await Isolate.spawn(_watchSelections, receivePort.sendPort);
      _isolate?.addOnExitListener(exitPort.sendPort);
    } catch (error, stackTrace) {
      talker.error(
        "Failed to start the XFixes selection watcher",
        error,
        stackTrace,
      );
      await stop();
    }
  }

  @override
  Future<void> stop() async {
    final isolate = _isolate;
    _isolate = null;
    if (isolate != null) {
      // Ask the isolate to exit on its own so it destroys its window
      // and closes its display connection; killing it would leak both.
      // The isolate sends its control port first thing, but spawn
      // returns before it has: wait briefly for the handshake (or for
      // the isolate to exit on its own) instead of killing a live one.
      final exited = Completer<void>();
      final exitSubscription = _exitPort?.listen((_) {
        if (!exited.isCompleted) exited.complete();
      });
      try {
        final handshakeDeadline = DateTime.now().add(
          const Duration(seconds: 1),
        );
        while (_isolateControl == null &&
            !exited.isCompleted &&
            DateTime.now().isBefore(handshakeDeadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        _isolateControl?.send(null);
        _isolateControl = null;
        try {
          await exited.future.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          isolate.kill(priority: Isolate.immediate);
        }
      } finally {
        await exitSubscription?.cancel();
      }
    }
    _exitPort?.close();
    _exitPort = null;
    await _subscription?.cancel();
    _subscription = null;
    _receivePort?.close();
    _receivePort = null;
    if (!_controller.isClosed) await _controller.close();
  }
}

/// The watcher isolate: subscribe to PRIMARY owner changes and forward
/// them. Reports the current owner state once at startup, then one event
/// per owner change. Never throws out of the isolate: a failure simply
/// ends the event stream.
///
/// The loop polls `XPending` instead of blocking in `XNextEvent`, and
/// awaits between polls so the control port's listener can run: a
/// blocking loop could never notice the stop message, and a killed
/// isolate never runs its `finally` block, which would leak the display
/// connection and the event window.
Future<void> _watchSelections(SendPort sendPort) async {
  final bindings = X11Bindings.openInIsolate();
  if (bindings == null) return;
  final xfixes = _openXFixes();
  if (xfixes == null) return;
  final display = bindings.openDisplay(nullptr);
  if (display == nullptr) return;
  final controlPort = ReceivePort();
  var stopRequested = false;
  controlPort.listen((_) {
    stopRequested = true;
  });
  sendPort.send(controlPort.sendPort);
  var window = 0;
  try {
    // The event base is read once here; the loop below compares against it.
    final base = _queryEventBase(bindings, xfixes, display);
    if (base == null) return;

    final primary = bindings.internAtomByName(display, "PRIMARY");
    window = bindings.createSimpleWindow(
      display,
      bindings.defaultRootWindow(display),
      0,
      0,
      1,
      1,
      0,
      0,
      0,
    );
    if (window == 0) return;
    xfixes.selectSelectionInput(
      display,
      window,
      primary,
      _selectionOwnerNotifyMask,
    );
    bindings.flush(display);

    sendPort.send(bindings.getSelectionOwner(display, primary) != 0);

    final event = bindings.allocBytes(192);
    try {
      while (!stopRequested) {
        if (bindings.pending(display) <= 0) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          continue;
        }
        bindings.nextEvent(display, event.cast<Void>());
        if (event.cast<Int32>()[0] != base) continue;
        // XFixesSelectionNotifyEvent layout (x86-64): window at byte 32,
        // subtype at byte 40, owner at byte 48, selection at byte 56.
        // Subtype is a 4-byte int: read it as Int32, not as the 8-byte
        // word holding it — the upper half is struct padding and carries
        // garbage (observed 0x5C6F), which dropped every event.
        final words = event.cast<Uint64>();
        if (event.cast<Int32>()[10] != _setSelectionOwnerNotify) continue;
        if (words[7] != primary) continue;
        sendPort.send(words[6] != 0);
      }
    } finally {
      bindings.freePointer(event);
    }
  } catch (_) {
    // The watcher is best-effort: any failure ends the stream silently.
  } finally {
    if (window != 0) bindings.destroyWindow(display, window);
    bindings.closeDisplay(display);
    controlPort.close();
  }
}

/// The two XFixes entry points the watcher isolate needs.
class _XFixes {
  _XFixes(this.queryExtension, this.selectSelectionInput);

  final _XFixesQueryExtensionDart queryExtension;
  final _XFixesSelectSelectionInputDart selectSelectionInput;
}

_XFixes? _openXFixes() {
  try {
    final xfixes = DynamicLibrary.open("libXfixes.so.3");
    return _XFixes(
      xfixes.lookupFunction<
        _XFixesQueryExtensionNative,
        _XFixesQueryExtensionDart
      >("XFixesQueryExtension"),
      xfixes.lookupFunction<
        _XFixesSelectSelectionInputNative,
        _XFixesSelectSelectionInputDart
      >("XFixesSelectSelectionInput"),
    );
  } catch (_) {
    return null;
  }
}

/// The XFixes event base: XFixes events arrive as `eventBase + subtype`,
/// so the loop needs the base to recognise them.
int? _queryEventBase(
  X11Bindings bindings,
  _XFixes xfixes,
  Pointer<Void> display,
) {
  final eventBase = bindings.allocInt32();
  final errorBase = bindings.allocInt32();
  try {
    if (xfixes.queryExtension(display, eventBase, errorBase) == 0) {
      return null;
    }
    return eventBase.value;
  } finally {
    bindings.freePointer(eventBase);
    bindings.freePointer(errorBase);
  }
}

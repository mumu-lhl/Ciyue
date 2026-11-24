import "dart:ffi";

import "package:ciyue/core/app_globals.dart";

/// Sends a synthetic copy keystroke (Ctrl+C on X11) so the application
/// holding the selection copies it onto the clipboard.
abstract class CopyKeySender {
  Future<bool> sendCopy();
}

// `XOpenDisplay` takes a `const char *` display name; it is typed as
// `Pointer<Void>` here so this file needs only `dart:ffi` (no `ffi` package
// dependency) — the only value ever passed is `nullptr` for the default
// display.
typedef _XOpenDisplayNative = Pointer<Void> Function(Pointer<Void>);
typedef _XOpenDisplayDart = Pointer<Void> Function(Pointer<Void>);

typedef _XCloseDisplayNative = Int32 Function(Pointer<Void>);
typedef _XCloseDisplayDart = int Function(Pointer<Void>);

typedef _XKeysymToKeycodeNative = Uint8 Function(Pointer<Void>, Uint32);
typedef _XKeysymToKeycodeDart = int Function(Pointer<Void>, int);

typedef _XFlushNative = Int32 Function(Pointer<Void>);
typedef _XFlushDart = int Function(Pointer<Void>);

typedef _XTestFakeKeyEventNative = Int32 Function(
  Pointer<Void>,
  Uint32,
  Int32,
  Uint64,
);
typedef _XTestFakeKeyEventDart = int Function(Pointer<Void>, int, int, int);

// X11 keysyms (keysymdef.h): Control_L and lowercase c.
const _keyControlL = 0xffe3;
const _keyC = 0x63;

/// Sends Ctrl+C through libXtst via pure Dart FFI — no native plugin and no
/// C code, so there is nothing to build per platform and no plugin to
/// register. X11 only; other platforms get [UnsupportedCopyKeySender].
class XTestCopyKeySender implements CopyKeySender {
  const XTestCopyKeySender();

  static bool? _available;

  /// Whether a synthetic Ctrl+C can be sent in this process.
  ///
  /// True only when both libraries open, the XTest symbol resolves, and a
  /// display connection succeeds. The result is cached: probing opens a
  /// display connection, which is not something to repeat per lookup. Never
  /// throws — an unavailable XTest simply means the clipboard-only ladder.
  static bool get isAvailable {
    final cached = _available;
    if (cached != null) return cached;
    try {
      final x11 = DynamicLibrary.open("libX11.so.6");
      final xtst = DynamicLibrary.open("libXtst.so.6");
      final openDisplay = x11
          .lookupFunction<_XOpenDisplayNative, _XOpenDisplayDart>(
            "XOpenDisplay",
          );
      final closeDisplay = x11
          .lookupFunction<_XCloseDisplayNative, _XCloseDisplayDart>(
            "XCloseDisplay",
          );
      xtst.lookupFunction<_XTestFakeKeyEventNative, _XTestFakeKeyEventDart>(
        "XTestFakeKeyEvent",
      );
      final display = openDisplay(nullptr);
      if (display == nullptr) {
        _available = false;
        return false;
      }
      closeDisplay(display);
      _available = true;
      return true;
    } catch (error, stackTrace) {
      talker.warning("XTest synthetic copy is unavailable", error, stackTrace);
      _available = false;
      return false;
    }
  }

  /// Dispatches Control down, C down/up, Control up, then flushes.
  ///
  /// Returns false — never throws — when the libraries or the display are
  /// unavailable, or a keycode has no mapping. All four events are sent
  /// even if an earlier one fails, so a modifier is never left held down.
  @override
  Future<bool> sendCopy() async {
    try {
      final x11 = DynamicLibrary.open("libX11.so.6");
      final xtst = DynamicLibrary.open("libXtst.so.6");
      final openDisplay = x11
          .lookupFunction<_XOpenDisplayNative, _XOpenDisplayDart>(
            "XOpenDisplay",
          );
      final closeDisplay = x11
          .lookupFunction<_XCloseDisplayNative, _XCloseDisplayDart>(
            "XCloseDisplay",
          );
      final keysymToKeycode = x11
          .lookupFunction<_XKeysymToKeycodeNative, _XKeysymToKeycodeDart>(
            "XKeysymToKeycode",
          );
      final flush = x11.lookupFunction<_XFlushNative, _XFlushDart>("XFlush");
      final fakeKeyEvent = xtst
          .lookupFunction<_XTestFakeKeyEventNative, _XTestFakeKeyEventDart>(
            "XTestFakeKeyEvent",
          );

      final display = openDisplay(nullptr);
      if (display == nullptr) return false;
      try {
        final control = keysymToKeycode(display, _keyControlL);
        final c = keysymToKeycode(display, _keyC);
        if (control == 0 || c == 0) return false;
        var ok = true;
        ok = fakeKeyEvent(display, control, 1, 0) != 0 && ok;
        ok = fakeKeyEvent(display, c, 1, 0) != 0 && ok;
        ok = fakeKeyEvent(display, c, 0, 0) != 0 && ok;
        ok = fakeKeyEvent(display, control, 0, 0) != 0 && ok;
        flush(display);
        return ok;
      } finally {
        closeDisplay(display);
      }
    } catch (error, stackTrace) {
      talker.error("Failed to send synthetic Ctrl+C", error, stackTrace);
      return false;
    }
  }
}

/// Windows/macOS stand-in: there is no XTest here, so no keystroke is ever
/// sent and the ladder falls back to the clipboard. Phase 2 replaces this
/// with SendInput/CGEvent senders.
class UnsupportedCopyKeySender implements CopyKeySender {
  const UnsupportedCopyKeySender();

  @override
  Future<bool> sendCopy() async => false;
}

import "dart:convert";
import "dart:ffi";
import "dart:io";
import "dart:isolate";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/selection_text_provider.dart";

// Pure Dart FFI against libX11 (and libc for allocation), following
// desktop_selection_xtest.dart: no `ffi` package dependency, so pointers
// are typed as Pointer<Void> and native memory comes from libc's calloc.
// Dart 3.14 rejects sizeOf on a type parameter, so allocation helpers take
// explicit byte sizes instead of a generic sizeOf<T>.

typedef _CallocNative = Pointer<Void> Function(Uint64, Uint64);
typedef _CallocDart = Pointer<Void> Function(int, int);
typedef _LibcFreeNative = Void Function(Pointer<Void>);
typedef _LibcFreeDart = void Function(Pointer<Void>);

typedef _XOpenDisplayNative = Pointer<Void> Function(Pointer<Void>);
typedef _XOpenDisplayDart = Pointer<Void> Function(Pointer<Void>);

typedef _XCloseDisplayNative = Int32 Function(Pointer<Void>);
typedef _XCloseDisplayDart = int Function(Pointer<Void>);

typedef _XDefaultRootWindowNative = Uint64 Function(Pointer<Void>);
typedef _XDefaultRootWindowDart = int Function(Pointer<Void>);

typedef _XCreateSimpleWindowNative = Uint64 Function(
  Pointer<Void>,
  Uint64,
  Int32,
  Int32,
  Uint32,
  Uint32,
  Uint32,
  Uint64,
  Uint64,
);
typedef _XCreateSimpleWindowDart = int Function(
  Pointer<Void>,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
);

typedef _XDestroyWindowNative = Int32 Function(Pointer<Void>, Uint64);
typedef _XDestroyWindowDart = int Function(Pointer<Void>, int);

typedef _XInternAtomNative = Uint64 Function(
  Pointer<Void>,
  Pointer<Uint8>,
  Int32,
);
typedef _XInternAtomDart = int Function(Pointer<Void>, Pointer<Uint8>, int);

typedef _XConvertSelectionNative = Int32 Function(
  Pointer<Void>,
  Uint64,
  Uint64,
  Uint64,
  Uint64,
  Uint64,
);
typedef _XConvertSelectionDart = int Function(
  Pointer<Void>,
  int,
  int,
  int,
  int,
  int,
);

typedef _XPendingNative = Int32 Function(Pointer<Void>);
typedef _XPendingDart = int Function(Pointer<Void>);

typedef _XNextEventNative = Int32 Function(Pointer<Void>, Pointer<Void>);
typedef _XNextEventDart = int Function(Pointer<Void>, Pointer<Void>);

typedef _XFlushNative = Int32 Function(Pointer<Void>);
typedef _XFlushDart = int Function(Pointer<Void>);

typedef _XGetWindowPropertyNative = Int32 Function(
  Pointer<Void>,
  Uint64,
  Uint64,
  Int64,
  Int64,
  Int32,
  Uint64,
  Pointer<Uint64>,
  Pointer<Int32>,
  Pointer<Uint64>,
  Pointer<Uint64>,
  Pointer<Pointer<Uint8>>,
);
typedef _XGetWindowPropertyDart = int Function(
  Pointer<Void>,
  int,
  int,
  int,
  int,
  int,
  int,
  Pointer<Uint64>,
  Pointer<Int32>,
  Pointer<Uint64>,
  Pointer<Uint64>,
  Pointer<Pointer<Uint8>>,
);

typedef _XFreeNative = Int32 Function(Pointer<Void>);
typedef _XFreeDart = int Function(Pointer<Void>);

typedef _XGetSelectionOwnerNative = Uint64 Function(Pointer<Void>, Uint64);
typedef _XGetSelectionOwnerDart = int Function(Pointer<Void>, int);

typedef _XKeysymToKeycodeNative = Uint8 Function(Pointer<Void>, Uint32);
typedef _XKeysymToKeycodeDart = int Function(Pointer<Void>, int);

typedef _XQueryKeymapNative = Int32 Function(Pointer<Void>, Pointer<Uint8>);
typedef _XQueryKeymapDart = int Function(Pointer<Void>, Pointer<Uint8>);

typedef _XGetModifierMappingNative = Pointer<Void> Function(Pointer<Void>);
typedef _XGetModifierMappingDart = Pointer<Void> Function(Pointer<Void>);

typedef _XFreeModifiermapNative = Int32 Function(Pointer<Void>);
typedef _XFreeModifiermapDart = int Function(Pointer<Void>);

typedef _XGetInputFocusNative = Int32 Function(
  Pointer<Void>,
  Pointer<Uint64>,
  Pointer<Int32>,
);
typedef _XGetInputFocusDart = int Function(
  Pointer<Void>,
  Pointer<Uint64>,
  Pointer<Int32>,
);

typedef _XGetClassHintNative = Int32 Function(
  Pointer<Void>,
  Uint64,
  Pointer<Void>,
);
typedef _XGetClassHintDart = int Function(Pointer<Void>, int, Pointer<Void>);

/// `Status XQueryTree(Display*, Window, Window*, Window*, Window**,
/// unsigned int*)`: the parent of a window, for walking from a focused
/// child window (a toolkit's text field) up to the toplevel that carries
/// WM_CLASS.
typedef _XQueryTreeNative = Int32 Function(
  Pointer<Void>,
  Uint64,
  Pointer<Uint64>,
  Pointer<Uint64>,
  Pointer<Pointer<Uint64>>,
  Pointer<Uint32>,
);
typedef _XQueryTreeDart = int Function(
  Pointer<Void>,
  int,
  Pointer<Uint64>,
  Pointer<Uint64>,
  Pointer<Pointer<Uint64>>,
  Pointer<Uint32>,
);

typedef _XSyncNative = Int32 Function(Pointer<Void>, Int32);
typedef _XSyncDart = int Function(Pointer<Void>, int);

typedef _XSetErrorHandlerNative = Pointer<Void> Function(Pointer<Void>);
typedef _XSetErrorHandlerDart = Pointer<Void> Function(Pointer<Void>);

// SelectionNotify, the event a conversion request answers with (X.h).
const _selectionNotify = 31;

// XEvent is a 192-byte union; the event type is the first int.
const _xEventSize = 192;

/// Zeroed native memory from libc, freed with [X11Bindings.free].
class _LibcAllocator implements Allocator {
  _LibcAllocator(this._calloc, this._free);

  final _CallocDart _calloc;
  final _LibcFreeDart _free;

  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    return _calloc(1, byteCount).cast<T>();
  }

  @override
  void free(Pointer<NativeType> pointer) => _free(pointer.cast<Void>());
}

/// The libX11 entry points Lane A needs, loaded once per isolate.
///
/// Every function here is resolved lazily from the opened library; a missing
/// symbol fails at lookup time, inside a try/catch at the call site, never
/// at import time.
class X11Bindings {
  X11Bindings._(DynamicLibrary x11, this._allocator)
    : openDisplay = x11.lookupFunction<_XOpenDisplayNative, _XOpenDisplayDart>(
        "XOpenDisplay",
      ),
      closeDisplay = x11
          .lookupFunction<_XCloseDisplayNative, _XCloseDisplayDart>(
            "XCloseDisplay",
          ),
      defaultRootWindow = x11
          .lookupFunction<_XDefaultRootWindowNative, _XDefaultRootWindowDart>(
            "XDefaultRootWindow",
          ),
      createSimpleWindow = x11
          .lookupFunction<_XCreateSimpleWindowNative, _XCreateSimpleWindowDart>(
            "XCreateSimpleWindow",
          ),
      destroyWindow = x11
          .lookupFunction<_XDestroyWindowNative, _XDestroyWindowDart>(
            "XDestroyWindow",
          ),
      internAtom = x11.lookupFunction<_XInternAtomNative, _XInternAtomDart>(
        "XInternAtom",
      ),
      convertSelection = x11
          .lookupFunction<_XConvertSelectionNative, _XConvertSelectionDart>(
            "XConvertSelection",
          ),
      pending = x11.lookupFunction<_XPendingNative, _XPendingDart>("XPending"),
      nextEvent = x11.lookupFunction<_XNextEventNative, _XNextEventDart>(
        "XNextEvent",
      ),
      flush = x11.lookupFunction<_XFlushNative, _XFlushDart>("XFlush"),
      getWindowProperty = x11
          .lookupFunction<_XGetWindowPropertyNative, _XGetWindowPropertyDart>(
            "XGetWindowProperty",
          ),
      free = x11.lookupFunction<_XFreeNative, _XFreeDart>("XFree"),
      getSelectionOwner = x11
          .lookupFunction<_XGetSelectionOwnerNative, _XGetSelectionOwnerDart>(
            "XGetSelectionOwner",
          ),
      keysymToKeycode = x11
          .lookupFunction<_XKeysymToKeycodeNative, _XKeysymToKeycodeDart>(
            "XKeysymToKeycode",
          ),
      queryKeymap = x11.lookupFunction<_XQueryKeymapNative, _XQueryKeymapDart>(
        "XQueryKeymap",
      ),
      getModifierMapping = x11
          .lookupFunction<_XGetModifierMappingNative, _XGetModifierMappingDart>(
            "XGetModifierMapping",
          ),
      freeModifiermap = x11
          .lookupFunction<_XFreeModifiermapNative, _XFreeModifiermapDart>(
            "XFreeModifiermap",
          ),
      getInputFocus = x11
          .lookupFunction<_XGetInputFocusNative, _XGetInputFocusDart>(
            "XGetInputFocus",
          ),
      getClassHint = x11
          .lookupFunction<_XGetClassHintNative, _XGetClassHintDart>(
            "XGetClassHint",
          ),
      queryTree = x11.lookupFunction<_XQueryTreeNative, _XQueryTreeDart>(
        "XQueryTree",
      ),
      sync = x11.lookupFunction<_XSyncNative, _XSyncDart>("XSync"),
      setErrorHandler = x11
          .lookupFunction<_XSetErrorHandlerNative, _XSetErrorHandlerDart>(
            "XSetErrorHandler",
          );

  static X11Bindings? _instance;

  /// The process-wide bindings, or null when libX11 cannot be opened.
  /// Each isolate that needs X11 builds its own instance instead: a
  /// [DynamicLibrary] handle must not be shared across isolates.
  static X11Bindings? get instance {
    final existing = _instance;
    if (existing != null) return existing;
    try {
      final x11 = DynamicLibrary.open("libX11.so.6");
      final libc = DynamicLibrary.open("libc.so.6");
      final allocator = _LibcAllocator(
        libc.lookupFunction<_CallocNative, _CallocDart>("calloc"),
        libc.lookupFunction<_LibcFreeNative, _LibcFreeDart>("free"),
      );
      return _instance = X11Bindings._(x11, allocator);
    } catch (error, stackTrace) {
      talker.warning("libX11 is unavailable", error, stackTrace);
      return null;
    }
  }

  /// A fresh bindings instance for a spawned isolate. Never throws: null
  /// when libX11 cannot be opened there.
  static X11Bindings? openInIsolate() {
    try {
      final x11 = DynamicLibrary.open("libX11.so.6");
      final libc = DynamicLibrary.open("libc.so.6");
      final allocator = _LibcAllocator(
        libc.lookupFunction<_CallocNative, _CallocDart>("calloc"),
        libc.lookupFunction<_LibcFreeNative, _LibcFreeDart>("free"),
      );
      return X11Bindings._(x11, allocator);
    } catch (_) {
      return null;
    }
  }

  /// Whether an X display connection can be opened in this process.
  ///
  /// Cached like [XTestCopyKeySender.isAvailable]: probing opens a display
  /// connection, which is not something to repeat per lookup. Never throws.
  static bool get isDisplayAvailable {
    final cached = _displayAvailable;
    if (cached != null) return cached;
    try {
      final bindings = instance;
      if (bindings == null) {
        _displayAvailable = false;
        return false;
      }
      final display = bindings.openDisplay(nullptr);
      if (display == nullptr) {
        _displayAvailable = false;
        return false;
      }
      bindings.closeDisplay(display);
      _displayAvailable = true;
      return true;
    } catch (error, stackTrace) {
      talker.warning("X display is unavailable", error, stackTrace);
      _displayAvailable = false;
      return false;
    }
  }

  static bool? _displayAvailable;

  final _LibcAllocator _allocator;

  final Pointer<Void> Function(Pointer<Void>) openDisplay;
  final int Function(Pointer<Void>) closeDisplay;
  final int Function(Pointer<Void>) defaultRootWindow;
  final int Function(Pointer<Void>, int, int, int, int, int, int, int, int)
  createSimpleWindow;
  final int Function(Pointer<Void>, int) destroyWindow;
  final int Function(Pointer<Void>, Pointer<Uint8>, int) internAtom;
  final int Function(Pointer<Void>, int, int, int, int, int) convertSelection;
  final int Function(Pointer<Void>) pending;
  final int Function(Pointer<Void>, Pointer<Void>) nextEvent;
  final int Function(Pointer<Void>) flush;
  final int Function(
    Pointer<Void>,
    int,
    int,
    int,
    int,
    int,
    int,
    Pointer<Uint64>,
    Pointer<Int32>,
    Pointer<Uint64>,
    Pointer<Uint64>,
    Pointer<Pointer<Uint8>>,
  )
  getWindowProperty;
  final int Function(Pointer<Void>) free;
  final int Function(Pointer<Void>, int) getSelectionOwner;
  final int Function(Pointer<Void>, int) keysymToKeycode;
  final int Function(Pointer<Void>, Pointer<Uint8>) queryKeymap;
  final Pointer<Void> Function(Pointer<Void>) getModifierMapping;
  final int Function(Pointer<Void>) freeModifiermap;
  final int Function(Pointer<Void>, Pointer<Uint64>, Pointer<Int32>)
  getInputFocus;
  final int Function(Pointer<Void>, int, Pointer<Void>) getClassHint;
  final int Function(
    Pointer<Void>,
    int,
    Pointer<Uint64>,
    Pointer<Uint64>,
    Pointer<Pointer<Uint64>>,
    Pointer<Uint32>,
  )
  queryTree;
  final int Function(Pointer<Void>, int) sync;
  final Pointer<Void> Function(Pointer<Void>) setErrorHandler;

  Pointer<Uint8> allocBytes(int byteCount) =>
      _allocator.allocate<Uint8>(byteCount);

  Pointer<Int32> allocInt32() => _allocator.allocate<Int32>(4);

  Pointer<Uint64> allocUint64() => _allocator.allocate<Uint64>(8);

  Pointer<Pointer<Uint8>> allocPointer() =>
      _allocator.allocate<Pointer<Uint8>>(8);

  void freePointer(Pointer pointer) => _allocator.free(pointer.cast());

  /// A NUL-terminated copy of [text], freed with [freePointer].
  Pointer<Uint8> toCString(String text) {
    final units = text.codeUnits;
    final pointer = allocBytes(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      pointer[i] = units[i];
    }
    pointer[units.length] = 0;
    return pointer;
  }

  /// The NUL-terminated string at [pointer], or "" for a null pointer.
  /// Only ASCII is expected here (atom names, WM_CLASS); non-ASCII bytes
  /// pass through as code units, which is good enough for an app id.
  static String readCString(Pointer<Void> pointer) {
    if (pointer == nullptr) return "";
    final bytes = <int>[];
    final raw = pointer.cast<Uint8>();
    var i = 0;
    while (true) {
      final byte = raw[i];
      if (byte == 0) break;
      bytes.add(byte);
      i++;
    }
    return String.fromCharCodes(bytes);
  }

  int internAtomByName(Pointer<Void> display, String name) {
    final pointer = toCString(name);
    try {
      return internAtom(display, pointer, 0);
    } finally {
      freePointer(pointer);
    }
  }
}

/// Reads the X11 PRIMARY selection directly, without touching the clipboard
/// and without faking a copy keystroke.
///
/// Linux X11 only. The blocking wait for the owner's reply runs in
/// [Isolate.run], never on the UI isolate: a non-responsive owner must stall
/// a throwaway isolate, not the app.
///
/// The X11 selection protocol carries no information about which window or
/// field the selection came from, so this provider cannot tell a password
/// field from a text field the way the AT-SPI2 and native providers can.
/// The only protection on this path is the call sites checking the focused
/// application against the user's exclusion list before acquiring any text
/// (`LookupHotkeyService.handleHotKey`, `LookupBubbleService`).
class X11PrimarySelectionProvider implements SelectionTextProvider {
  X11PrimarySelectionProvider({
    this.timeout = const Duration(milliseconds: 300),
  });

  /// How long to wait for the selection owner to answer a conversion
  /// request before giving up.
  final Duration timeout;

  /// Whether PRIMARY can be read in this process: libX11 opens and a
  /// display connection succeeds. Cached; never throws.
  static bool get isAvailable => X11Bindings.isDisplayAvailable;

  /// Returns null only when there is definitely no selection (no PRIMARY
  /// owner, or the owner cannot offer text). A timeout or any other
  /// failure throws [SelectionUnavailableException] so the ladder can try
  /// the next rung instead of reporting "no selection".
  @override
  Future<String?> getSelectedText() async {
    if (!isAvailable) {
      throw const SelectionUnavailableException("X display is unavailable");
    }
    try {
      final text = await Isolate.run(
        () => _readPrimarySelection(timeout.inMilliseconds),
      );
      final trimmed = text?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } on SelectionUnavailableException {
      rethrow;
    } catch (error, stackTrace) {
      talker.error("Failed to read the PRIMARY selection", error, stackTrace);
      throw const SelectionUnavailableException(
        "PRIMARY selection read failed",
      );
    }
  }
}

/// The isolate body for [X11PrimarySelectionProvider]: open a display,
/// ask the PRIMARY owner for the text, wait for the reply.
///
/// Runs in a fresh isolate, so it builds its own bindings and opens its
/// own display connection. Returns the raw selected text (untrimmed), or
/// null when there is no owner or the owner cannot offer text. Throws
/// [SelectionUnavailableException] when the owner never answers or the
/// read itself fails, so the ladder can try the next rung.
String? _readPrimarySelection(int timeoutMs) {
  final bindings = X11Bindings.openInIsolate();
  if (bindings == null) {
    throw const SelectionUnavailableException("libX11 could not be opened");
  }
  final display = bindings.openDisplay(nullptr);
  if (display == nullptr) {
    throw const SelectionUnavailableException("X display could not be opened");
  }
  var requestor = 0;
  try {
    final primary = bindings.internAtomByName(display, "PRIMARY");
    if (bindings.getSelectionOwner(display, primary) == 0) return null;

    requestor = bindings.createSimpleWindow(
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
    if (requestor == 0) {
      throw const SelectionUnavailableException(
        "requestor window could not be created",
      );
    }

    final property = bindings.internAtomByName(display, "CIYUE_PRIMARY_TEXT");
    final incrAtom = bindings.internAtomByName(display, "INCR");
    final utf8String = bindings.internAtomByName(display, "UTF8_STRING");
    final stringAtom = bindings.internAtomByName(display, "STRING");

    final text = _convertAndRead(
      bindings,
      display,
      requestor,
      primary,
      utf8String,
      property,
      timeoutMs,
      incrAtom,
      utf8.decode,
    );
    if (text != null) return text;
    // The owner only offers STRING (latin-1): accept that instead of
    // reporting nothing for a selection the user plainly made.
    return _convertAndRead(
      bindings,
      display,
      requestor,
      primary,
      stringAtom,
      property,
      timeoutMs,
      incrAtom,
      latin1.decode,
    );
  } on SelectionUnavailableException {
    rethrow;
  } catch (_) {
    throw const SelectionUnavailableException("PRIMARY selection read failed");
  } finally {
    if (requestor != 0) bindings.destroyWindow(display, requestor);
    bindings.closeDisplay(display);
  }
}

/// Asks the PRIMARY owner to convert the selection to [target], waits up to
/// [timeoutMs] for the SelectionNotify reply, and reads the property.
///
/// Returns the converted text, or null when the owner declines (the reply's
/// property is None). Throws [SelectionUnavailableException] when the owner
/// never answers, so the ladder can try the next rung instead of reporting
/// "no selection". [decode] turns the property bytes into text: UTF-8 for
/// UTF8_STRING, latin-1 for STRING.
String? _convertAndRead(
  X11Bindings bindings,
  Pointer<Void> display,
  int requestor,
  int selection,
  int target,
  int property,
  int timeoutMs,
  int incrAtom,
  String Function(List<int>) decode,
) {
  bindings.convertSelection(display, selection, target, property, requestor, 0);
  bindings.flush(display);

  final event = bindings.allocBytes(_xEventSize);
  try {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (DateTime.now().isBefore(deadline)) {
      if (bindings.pending(display) <= 0) {
        sleep(const Duration(milliseconds: 5));
        continue;
      }
      bindings.nextEvent(display, event.cast<Void>());
      if (event.cast<Int32>()[0] != _selectionNotify) continue;
      // XSelectionEvent layout (x86-64): requestor at byte 32, selection
      // at 40, target at 48, property at 56.
      final words = event.cast<Uint64>();
      // The target must match too: a late reply to an earlier conversion
      // (e.g. the UTF8_STRING request answered after the STRING retry
      // started) is stale, and its property belongs to that request.
      if (words[4] != requestor ||
          words[5] != selection ||
          words[6] != target) {
        continue;
      }
      if (words[7] == 0) return null;
      return _readProperty(
        bindings,
        display,
        requestor,
        property,
        target,
        incrAtom,
        decode,
      );
    }
    throw const SelectionUnavailableException(
      "selection owner did not answer in time",
    );
  } finally {
    bindings.freePointer(event);
  }
}

/// Reads [property] off [requestor] and decodes the bytes, deleting the
/// property once the whole value has been read.
///
/// The value is read in 1 MiB chunks until the server reports nothing left,
/// so a long selection comes back whole instead of silently truncated. The
/// reply must carry the requested [target] type in 8-bit format: anything
/// else is not the text asked for. An INCR transfer (the owner dribbles a
/// large value in through PropertyNotify events, a protocol this reader
/// does not implement) throws [SelectionUnavailableException] so the ladder
/// can try the next rung instead of misreading a partial value.
String? _readProperty(
  X11Bindings bindings,
  Pointer<Void> display,
  int requestor,
  int property,
  int target,
  int incrAtom,
  String Function(List<int>) decode,
) {
  final actualType = bindings.allocUint64();
  final actualFormat = bindings.allocInt32();
  final nitems = bindings.allocUint64();
  final bytesAfter = bindings.allocUint64();
  final value = bindings.allocPointer();
  try {
    // Offsets and lengths are in 32-bit units; a full 1 MiB chunk is
    // 262144 of them, so each further chunk resumes exactly where the
    // previous one ended.
    const chunkLongs = 262144;
    final bytes = <int>[];
    var offset = 0;
    while (true) {
      final status = bindings.getWindowProperty(
        display,
        requestor,
        property,
        offset,
        chunkLongs,
        0,
        0,
        actualType,
        actualFormat,
        nitems,
        bytesAfter,
        value,
      );
      if (status != 0) {
        throw const SelectionUnavailableException("XGetWindowProperty failed");
      }
      if (actualType.value == incrAtom) {
        throw const SelectionUnavailableException(
          "INCR selection transfer is not supported",
        );
      }
      if (actualType.value != target || actualFormat.value != 8) {
        throw const SelectionUnavailableException(
          "selection property has an unexpected type or format",
        );
      }
      final data = value.value;
      final count = nitems.value;
      if (data == nullptr || count == 0) break;
      bytes.addAll(data.asTypedList(count.toInt()));
      bindings.free(data.cast<Void>());
      if (bytesAfter.value == 0) break;
      offset += chunkLongs;
    }
    // A zero-length read with delete set removes the property now that
    // the whole value has been collected.
    bindings.getWindowProperty(
      display,
      requestor,
      property,
      0,
      0,
      1,
      0,
      actualType,
      actualFormat,
      nitems,
      bytesAfter,
      value,
    );
    if (bytes.isEmpty) return null;
    return decode(bytes);
  } finally {
    bindings.freePointer(actualType);
    bindings.freePointer(actualFormat);
    bindings.freePointer(nitems);
    bindings.freePointer(bytesAfter);
    bindings.freePointer(value);
  }
}

/// The modifier keys the lookup bubble checks at event time.
enum X11Modifier { control, alt, shift }

// X11 keysyms (keysymdef.h).
const _keysymShiftL = 0xffe1;
const _keysymShiftR = 0xffe2;
const _keysymControlL = 0xffe3;
const _keysymControlR = 0xffe4;
const _keysymAltL = 0xffe9;
const _keysymAltR = 0xffea;

/// Reads the live keyboard state through XQueryKeymap.
///
/// Which modifier row holds Control/Alt/Shift comes from
/// XGetModifierMapping, not from hardcoded bit positions: the server's
/// mapping is what decides it, and the row is found by locating the
/// modifier's keycode in the map (canonical row order is only the fallback
/// when a keysym has no mapping at all).
class X11ModifierState {
  X11ModifierState._();

  /// Whether the X display can be queried in this process. Never throws.
  static bool get isAvailable => X11Bindings.isDisplayAvailable;

  /// Whether [modifier] is currently held down. Never throws: any failure
  /// reads as "not held".
  static bool isHeld(X11Modifier modifier) {
    try {
      final bindings = X11Bindings.instance;
      if (bindings == null) return false;
      final display = bindings.openDisplay(nullptr);
      if (display == nullptr) return false;
      try {
        return _isHeld(bindings, display, modifier);
      } finally {
        bindings.closeDisplay(display);
      }
    } catch (error, stackTrace) {
      talker.warning(
        "Failed to read the X11 modifier state",
        error,
        stackTrace,
      );
      return false;
    }
  }

  static bool _isHeld(
    X11Bindings bindings,
    Pointer<Void> display,
    X11Modifier modifier,
  ) {
    final (keysyms, fallbackRow) = switch (modifier) {
      X11Modifier.control => ([_keysymControlL, _keysymControlR], 2),
      X11Modifier.alt => ([_keysymAltL, _keysymAltR], 3),
      X11Modifier.shift => ([_keysymShiftL, _keysymShiftR], 0),
    };

    final modifierMap = bindings.getModifierMapping(display);
    if (modifierMap == nullptr) return false;
    try {
      // XModifierKeymap: int max_keypermod at byte 0, then an 8-row table
      // of keycodes at byte 8. Row order is Shift, Lock, Control, Mod1-5.
      final maxPerMod = modifierMap.cast<Int32>()[0];
      if (maxPerMod <= 0) return false;
      final table = modifierMap.cast<Pointer<Uint8>>()[1];
      if (table == nullptr) return false;

      var row = -1;
      for (final keysym in keysyms) {
        final keycode = bindings.keysymToKeycode(display, keysym);
        if (keycode == 0) continue;
        for (var r = 0; r < 8; r++) {
          for (var i = 0; i < maxPerMod; i++) {
            if (table[r * maxPerMod + i] == keycode) row = r;
          }
        }
      }
      row = row < 0 ? fallbackRow : row;

      final keymap = bindings.allocBytes(32);
      try {
        bindings.queryKeymap(display, keymap);
        for (var i = 0; i < maxPerMod; i++) {
          final keycode = table[row * maxPerMod + i];
          if (keycode == 0) continue;
          if ((keymap[keycode >> 3] & (1 << (keycode & 7))) != 0) {
            return true;
          }
        }
        return false;
      } finally {
        bindings.freePointer(keymap);
      }
    } finally {
      bindings.freeModifiermap(modifierMap);
    }
  }
}

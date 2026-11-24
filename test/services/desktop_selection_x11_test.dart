import "dart:async";
import "dart:ffi";
import "dart:io";

import "package:ciyue/services/desktop_selection_x11.dart";
import "package:ciyue/services/focused_app_x11.dart";
import "package:ciyue/services/selection_text_provider.dart";
import "package:ciyue/services/selection_watcher_x11.dart";
import "package:flutter_test/flutter_test.dart";

// Lane A X11 tests. They drive a real X display (PRIMARY ownership,
// XFixes events, input focus, keymap state), so they are skipped without
// one. All groups live in this one file on purpose: the tests share the
// single PRIMARY selection, and files run concurrently under `flutter
// test`, so splitting them would let one file's selection owner overwrite
// another's mid-assertion.

/// An X error handler that swallows the error: focusing a window races the
/// window manager's reparenting (the window is not viewable until the WM
/// maps its frame), and the resulting BadMatch on X_SetInputFocus kills
/// the test shell under the default handler. Installed once per test
/// process; the pointer is held for the life of the process.
int _swallowXError(Pointer<Void> display, Pointer<Void> errorEvent) => 0;

final Pointer<NativeFunction<Int32 Function(Pointer<Void>, Pointer<Void>)>>
_swallowingErrorHandler =
    Pointer.fromFunction<Int32 Function(Pointer<Void>, Pointer<Void>)>(
      _swallowXError,
      0,
    );
final bool _hasDisplay = (Platform.environment["DISPLAY"] ?? "").isNotEmpty;
final bool _hasXclip = _which("xclip");

// X11 keysyms (keysymdef.h) for the modifier rows under test.
const _keysymShiftL = 0xffe1;
const _keysymControlL = 0xffe3;
const _keysymAltL = 0xffe9;

/// Opens a test X client, or skips the test when no display is available.
/// Returns a non-null client: [markTestSkipped] throws, so a null open
/// never falls through.
_TestXClient _requireClient() {
  final client = _TestXClient.open();
  if (client != null) return client;
  markTestSkipped("could not open an X display");
  throw StateError("unreachable: markTestSkipped always throws");
}

bool _which(String program) {
  try {
    return Process.runSync("which", [program]).exitCode == 0;
  } catch (_) {
    return false;
  }
}

/// Waits up to [timeout] for [condition] to become true, polling every
/// 50ms. Throws a [TimeoutException] when the condition never holds.
Future<void> _waitFor(bool Function() condition, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (!DateTime.now().isBefore(deadline)) {
      throw TimeoutException("condition not met within $timeout");
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

/// A minimal X11 client for the tests: owns the PRIMARY selection, sets a
/// window class, and moves input focus. Pure Dart FFI, independent of the
/// implementation under test except for the atom names every X11 client
/// shares.
class _TestXClient {
  static _TestXClient? open() {
    try {
      final x11 = DynamicLibrary.open("libX11.so.6");
      final libc = DynamicLibrary.open("libc.so.6");
      final calloc = libc
          .lookupFunction<
            Pointer<Void> Function(Uint64, Uint64),
            Pointer<Void> Function(int, int)
          >("calloc");
      final free = libc
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >("free");
      final openDisplay = x11
          .lookupFunction<
            Pointer<Void> Function(Pointer<Void>),
            Pointer<Void> Function(Pointer<Void>)
          >("XOpenDisplay");
      final display = openDisplay(nullptr);
      if (display == nullptr) return null;
      // A focus request that races the window manager's reparenting raises
      // BadMatch, which the default handler turns into a fatal shell
      // crash; swallow X errors for the whole test process instead.
      final setErrorHandler = x11
          .lookupFunction<
            Pointer<Void> Function(Pointer<Void>),
            Pointer<Void> Function(Pointer<Void>)
          >("XSetErrorHandler");
      setErrorHandler(_swallowingErrorHandler.cast<Void>());
      return _TestXClient._(x11, display, calloc, free);
    } catch (_) {
      return null;
    }
  }

  _TestXClient._(this._x11, this._display, this._calloc, this._free);

  final DynamicLibrary _x11;
  final Pointer<Void> _display;
  final Pointer<Void> Function(int, int) _calloc;
  final void Function(Pointer<Void>) _free;

  Pointer<Uint8> _cString(String text) {
    final units = text.codeUnits;
    final pointer = _calloc(1, units.length + 1).cast<Uint8>();
    for (var i = 0; i < units.length; i++) {
      pointer[i] = units[i];
    }
    pointer[units.length] = 0;
    return pointer;
  }

  int _atom(String name) {
    final internAtom = _x11
        .lookupFunction<
          Uint64 Function(Pointer<Void>, Pointer<Uint8>, Int32),
          int Function(Pointer<Void>, Pointer<Uint8>, int)
        >("XInternAtom");
    final pointer = _cString(name);
    try {
      return internAtom(_display, pointer, 0);
    } finally {
      _free(pointer.cast<Void>());
    }
  }

  int _rootWindow() {
    final root = _x11
        .lookupFunction<
          Uint64 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >("XDefaultRootWindow");
    return root(_display);
  }

  int createWindow() {
    final create = _x11
        .lookupFunction<
          Uint64 Function(
            Pointer<Void>,
            Uint64,
            Int32,
            Int32,
            Uint32,
            Uint32,
            Uint32,
            Uint64,
            Uint64,
          ),
          int Function(Pointer<Void>, int, int, int, int, int, int, int, int)
        >("XCreateSimpleWindow");
    return create(_display, _rootWindow(), 0, 0, 1, 1, 0, 0, 0);
  }

  /// A child window of [parent] with no WM_CLASS of its own, the way a
  /// toolkit's focused text field is a child of its toplevel.
  int createChildWindow(int parent) {
    final create = _x11
        .lookupFunction<
          Uint64 Function(
            Pointer<Void>,
            Uint64,
            Int32,
            Int32,
            Uint32,
            Uint32,
            Uint32,
            Uint64,
            Uint64,
          ),
          int Function(Pointer<Void>, int, int, int, int, int, int, int, int)
        >("XCreateSimpleWindow");
    return create(_display, parent, 0, 0, 1, 1, 0, 0, 0);
  }

  /// Gives [window] input focus (mapping it first: an unmapped window
  /// cannot take focus).
  void focusWindow(int window) {
    mapWindow(window);
    _setFocusWithRetry(window);
  }

  /// Sets input focus on [window], retrying until the server reports it:
  /// the window is not viewable until the window manager reparents and
  /// maps its frame, so the first request can fail with BadMatch. The
  /// process-wide swallowing handler (see [_TestXClient.open]) keeps a
  /// failed attempt from killing the test shell; giving up silently here
  /// leaves a clear assertion failure in the test instead of a crash.
  void _setFocusWithRetry(int window) {
    final setFocus = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>, Uint64, Int32, Uint64),
          int Function(Pointer<Void>, int, int, int)
        >("XSetInputFocus");
    final getFocus = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>, Pointer<Uint64>, Pointer<Int32>),
          int Function(Pointer<Void>, Pointer<Uint64>, Pointer<Int32>)
        >("XGetInputFocus");
    for (var attempt = 0; attempt < 20; attempt++) {
      setFocus(_display, window, 2, 0);
      flush();
      sleep(const Duration(milliseconds: 100));
      final focus = _calloc(1, 8).cast<Uint64>();
      final revertTo = _calloc(1, 4).cast<Int32>();
      try {
        getFocus(_display, focus, revertTo);
        if (focus.value == window) return;
      } finally {
        _free(focus.cast<Void>());
        _free(revertTo.cast<Void>());
      }
    }
  }

  void destroyWindow(int window) {
    final destroy = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>, Uint64),
          int Function(Pointer<Void>, int)
        >("XDestroyWindow");
    destroy(_display, window);
  }

  void mapWindow(int window) {
    final map = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>, Uint64),
          int Function(Pointer<Void>, int)
        >("XMapWindow");
    map(_display, window);
    flush();
  }

  void flush() {
    final flush = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >("XFlush");
    flush(_display);
  }

  int pending() {
    final pending = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >("XPending");
    return pending(_display);
  }

  void nextEvent(Pointer<Uint8> event) {
    final nextEvent = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>, Pointer<Void>),
          int Function(Pointer<Void>, Pointer<Void>)
        >("XNextEvent");
    nextEvent(_display, event.cast<Void>());
  }

  void changeProperty(
    int window,
    int property,
    int type,
    int format,
    int mode,
    Pointer<Uint8> data,
    int nelements,
  ) {
    final changeProperty = _x11
        .lookupFunction<
          Int32 Function(
            Pointer<Void>,
            Uint64,
            Uint64,
            Uint64,
            Int32,
            Int32,
            Pointer<Uint8>,
            Int32,
          ),
          int Function(
            Pointer<Void>,
            int,
            int,
            int,
            int,
            int,
            Pointer<Uint8>,
            int,
          )
        >("XChangeProperty");
    changeProperty(
      _display,
      window,
      property,
      type,
      format,
      mode,
      data,
      nelements,
    );
  }

  /// Sends a SelectionNotify to [requestor] for [selection]/[target],
  /// carrying [property] (None when the conversion is declined).
  void sendNotify(
    int requestor,
    int selection,
    int target,
    int property,
    int time,
  ) {
    final sendEvent = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>, Uint64, Int32, Int64, Pointer<Void>),
          int Function(Pointer<Void>, int, int, int, Pointer<Void>)
        >("XSendEvent");
    final event = _calloc(1, 192).cast<Uint8>();
    try {
      event.cast<Int32>()[0] = 31; // SelectionNotify
      event.cast<Int32>()[4] = 1; // send_event
      final words = event.cast<Uint64>();
      words[3] = _display.address;
      words[4] = requestor;
      words[5] = selection;
      words[6] = target;
      words[7] = property;
      words[8] = time;
      sendEvent(_display, requestor, 0, 0, event.cast<Void>());
    } finally {
      _free(event.cast<Void>());
    }
    flush();
  }

  void close() {
    final close = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >("XCloseDisplay");
    close(_display);
  }

  static DynamicLibrary? _xTest;

  /// Whether XTest key injection is available in this process.
  static bool get hasXTest => _xTestLibrary() != null;

  static DynamicLibrary? _xTestLibrary() {
    final cached = _xTest;
    if (cached != null) return cached;
    try {
      final lib = DynamicLibrary.open("libXtst.so.6");
      lib.lookup<
        NativeFunction<Int32 Function(Pointer<Void>, Uint32, Int32, Uint64)>
      >("XTestFakeKeyEvent");
      return _xTest = lib;
    } catch (_) {
      return null;
    }
  }

  /// Presses the key for [keysym] via XTest and holds it down: the
  /// server releases XTest-injected keys when the injecting client
  /// disconnects, so a key held by a short-lived `xdotool keydown`
  /// process is already gone by the time the state is read — the key
  /// must be held from this open connection. Returns the keycode to
  /// release, or null when XTest is unavailable.
  int? pressKeyByKeysym(int keysym) {
    final lib = _xTestLibrary();
    if (lib == null) return null;
    final toKeycode = _x11
        .lookupFunction<
          Uint32 Function(Pointer<Void>, Uint64),
          int Function(Pointer<Void>, int)
        >("XKeysymToKeycode");
    final fakeKey = lib
        .lookupFunction<
          Int32 Function(Pointer<Void>, Uint32, Int32, Uint64),
          int Function(Pointer<Void>, int, int, int)
        >("XTestFakeKeyEvent");
    final keycode = toKeycode(_display, keysym);
    if (keycode == 0) return null;
    fakeKey(_display, keycode, 1, 0);
    flush();
    return keycode;
  }

  void releaseKey(int keycode) {
    final lib = _xTestLibrary();
    if (lib == null) return;
    final fakeKey = lib
        .lookupFunction<
          Int32 Function(Pointer<Void>, Uint32, Int32, Uint64),
          int Function(Pointer<Void>, int, int, int)
        >("XTestFakeKeyEvent");
    fakeKey(_display, keycode, 0, 0);
    flush();
  }

  /// Number of direct children of the root window, via XQueryTree.
  int countRootChildren() {
    final queryTree = _x11
        .lookupFunction<
          Int32 Function(
            Pointer<Void>,
            Uint64,
            Pointer<Uint64>,
            Pointer<Uint64>,
            Pointer<Pointer<Uint64>>,
            Pointer<Uint32>,
          ),
          int Function(
            Pointer<Void>,
            int,
            Pointer<Uint64>,
            Pointer<Uint64>,
            Pointer<Pointer<Uint64>>,
            Pointer<Uint32>,
          )
        >("XQueryTree");
    final freeList = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >("XFree");
    final root = _calloc(1, 8).cast<Uint64>();
    final parent = _calloc(1, 8).cast<Uint64>();
    final children = _calloc(1, 8).cast<Pointer<Uint64>>();
    final nchildren = _calloc(1, 4).cast<Uint32>();
    try {
      if (queryTree(
            _display,
            _rootWindow(),
            root,
            parent,
            children,
            nchildren,
          ) ==
          0) {
        throw StateError("XQueryTree failed");
      }
      final count = nchildren.value;
      if (children.value != nullptr) {
        freeList(children.value.cast<Void>());
      }
      return count;
    } finally {
      _free(root.cast<Void>());
      _free(parent.cast<Void>());
      _free(children.cast<Void>());
      _free(nchildren.cast<Void>());
    }
  }

  /// Takes PRIMARY ownership with [window] and never answers conversion
  /// requests: the connection processes no events, so the provider must
  /// time out instead of hanging.
  void ownPrimarySilently(int window) {
    final setOwner = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>, Uint64, Uint64, Uint64),
          int Function(Pointer<Void>, int, int, int)
        >("XSetSelectionOwner");
    setOwner(_display, _atom("PRIMARY"), window, 0);
    flush();
  }

  /// Releases PRIMARY ownership explicitly, the way a toolkit does when
  /// the user deselects.
  void clearPrimary() {
    final setOwner = _x11
        .lookupFunction<
          Int32 Function(Pointer<Void>, Uint64, Uint64, Uint64),
          int Function(Pointer<Void>, int, int, int)
        >("XSetSelectionOwner");
    setOwner(_display, _atom("PRIMARY"), 0, 0);
    flush();
  }

  /// Sets WM_CLASS on [window] (res_name, res_class) and gives it input
  /// focus, so the resolver can be checked end to end.
  void focusWindowWithClass(int window, String name, String className) {
    // The window must be viewable before it can take focus.
    mapWindow(window);
    final setClassHint = _x11
        .lookupFunction<
          Void Function(Pointer<Void>, Uint64, Pointer<Void>),
          void Function(Pointer<Void>, int, Pointer<Void>)
        >("XSetClassHint");
    final hint = _calloc(1, 16).cast<Pointer<Void>>();
    final namePtr = _cString(name);
    final classPtr = _cString(className);
    hint[0] = namePtr.cast<Void>();
    hint[1] = classPtr.cast<Void>();
    try {
      setClassHint(_display, window, hint.cast<Void>());
    } finally {
      _free(hint.cast<Void>());
      _free(namePtr.cast<Void>());
      _free(classPtr.cast<Void>());
    }
    _setFocusWithRetry(window);
  }
}

/// A minimal PRIMARY owner that only offers STRING (latin-1): it declines
/// UTF8_STRING, and answers STRING with latin-1 bytes. Before declining
/// UTF8_STRING it first sends a stale reply — a SelectionNotify with the
/// wrong target whose property holds different text — which the provider
/// must ignore instead of treating as the answer.
class _StringOnlySelectionOwner {
  _StringOnlySelectionOwner(this._client)
    : _utf8Atom = _client._atom("UTF8_STRING"),
      _stringAtom = _client._atom("STRING"),
      _garbageAtom = _client._atom("CIYUE_TEST_GARBAGE");

  final _TestXClient _client;
  final int _utf8Atom;
  final int _stringAtom;
  final int _garbageAtom;

  var _stopped = false;
  var bogusReplySent = false;
  var stringReplySent = false;

  void stop() => _stopped = true;

  Future<void> run() async {
    final event = _client._calloc(1, 192).cast<Uint8>();
    try {
      while (!_stopped) {
        if (_client.pending() > 0) {
          _client.nextEvent(event);
          _handleEvent(event);
        } else {
          await Future.delayed(const Duration(milliseconds: 5));
        }
      }
    } finally {
      _client._free(event.cast<Void>());
    }
  }

  void _handleEvent(Pointer<Uint8> event) {
    if (event.cast<Int32>()[0] != 30) return; // SelectionRequest
    // XSelectionRequestEvent layout (x86-64): requestor at byte 40,
    // selection at 48, target at 56, property at 64, time at 72.
    final words = event.cast<Uint64>();
    final requestor = words[5];
    final selection = words[6];
    final target = words[7];
    final property = words[8];
    final time = words[9];
    if (target == _utf8Atom) {
      final garbage = _client._cString("wrong text");
      try {
        _client.changeProperty(
          requestor,
          _garbageAtom,
          _stringAtom,
          8,
          0,
          garbage,
          10,
        );
      } finally {
        _client._free(garbage.cast<Void>());
      }
      _client.sendNotify(requestor, selection, _stringAtom, _garbageAtom, time);
      bogusReplySent = true;
      // The real answer: this owner offers no UTF8_STRING.
      _client.sendNotify(requestor, selection, _utf8Atom, 0, time);
    } else if (target == _stringAtom) {
      // "café" in latin-1: the 0xE9 byte is not valid UTF-8 on its own,
      // so only the STRING fallback can produce this text.
      final bytes = _client._calloc(1, 4).cast<Uint8>();
      bytes[0] = 0x63;
      bytes[1] = 0x61;
      bytes[2] = 0x66;
      bytes[3] = 0xE9;
      try {
        _client.changeProperty(
          requestor,
          property,
          _stringAtom,
          8,
          0,
          bytes,
          4,
        );
      } finally {
        _client._free(bytes.cast<Void>());
      }
      _client.sendNotify(requestor, selection, _stringAtom, property, time);
      stringReplySent = true;
    } else {
      _client.sendNotify(requestor, selection, target, 0, time);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("X11PrimarySelectionProvider", () {
    test(
      "returns text owned by another client",
      () async {
        final provider = X11PrimarySelectionProvider(
          timeout: const Duration(seconds: 2),
        );
        final xclip = await Process.start("xclip", [
          "-selection",
          "primary",
          "-i",
        ]);
        try {
          xclip.stdin.write("hello x11 primary");
          await xclip.stdin.close();
          await Future.delayed(const Duration(milliseconds: 300));
          expect(await provider.getSelectedText(), "hello x11 primary");
        } finally {
          await Process.run("pkill", ["-x", "xclip"]);
          await xclip.exitCode.timeout(
            const Duration(seconds: 2),
            onTimeout: () => 0,
          );
        }
      },
      skip: !_hasDisplay
          ? "requires a live X display"
          : !_hasXclip
          ? "requires xclip"
          : null,
    );

    test(
      "returns null when nothing owns PRIMARY",
      () async {
        // No owner: nothing sets the selection in this test process.
        await Process.run("pkill", ["-x", "xclip"]);
        await Future.delayed(const Duration(milliseconds: 200));
        expect(
          await X11PrimarySelectionProvider(
            timeout: const Duration(milliseconds: 300),
          ).getSelectedText(),
          isNull,
        );
      },
      skip: !_hasDisplay
          ? "requires a live X display"
          : !_hasXclip
          ? "requires xclip"
          : null,
    );

    test(
      "reads a STRING-only selection as latin-1 and ignores a stale reply",
      () async {
        final client = _requireClient();
        final window = client.createWindow();
        final owner = _StringOnlySelectionOwner(client);
        try {
          client.ownPrimarySilently(window);
          final ownerDone = owner.run();
          try {
            expect(
              await X11PrimarySelectionProvider(
                timeout: const Duration(seconds: 5),
              ).getSelectedText(),
              "café",
            );
            expect(owner.bogusReplySent, isTrue);
            expect(owner.stringReplySent, isTrue);
          } finally {
            owner.stop();
            await ownerDone;
          }
        } finally {
          client.clearPrimary();
          client.destroyWindow(window);
          client.close();
        }
      },
      skip: !_hasDisplay ? "requires a live X display" : null,
    );

    test(
      "reports the rung unavailable on timeout when the owner never answers",
      () async {
        final client = _requireClient();
        final window = client.createWindow();
        try {
          client.ownPrimarySilently(window);
          final stopwatch = Stopwatch()..start();
          await expectLater(
            X11PrimarySelectionProvider(
              timeout: const Duration(milliseconds: 300),
            ).getSelectedText(),
            throwsA(isA<SelectionUnavailableException>()),
          );
          stopwatch.stop();
          expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        } finally {
          client.clearPrimary();
          client.destroyWindow(window);
          client.close();
        }
      },
      skip: !_hasDisplay ? "requires a live X display" : null,
    );

    test("isAvailable follows the display", () {
      expect(X11PrimarySelectionProvider.isAvailable, isTrue);
    }, skip: !_hasDisplay ? "requires a live X display" : null);
  });

  group("XFixesSelectionWatcher", () {
    test("emits true on select and false on explicit clear", () async {
      final watcher = XFixesSelectionWatcher();
      expect(watcher.isAvailable, isTrue);
      final events = <bool>[];
      final subscription = watcher.onSelectionChanged.listen(events.add);
      try {
        await watcher.start();
        // The watcher reports the initial owner state on start; wait
        // for it before driving changes so a late initial event cannot
        // land after the driven ones.
        await _waitFor(() => events.isNotEmpty, const Duration(seconds: 10));
        events.clear();

        final client = _requireClient();
        final window = client.createWindow();
        try {
          client.ownPrimarySilently(window);
          client.clearPrimary();
          await _waitFor(() => events.length >= 2, const Duration(seconds: 10));
        } finally {
          client.destroyWindow(window);
          client.close();
        }
        expect(events, [true, false]);
      } finally {
        await watcher.stop();
        await subscription.cancel();
      }
    }, skip: !_hasDisplay ? "requires a live X display" : null);

    test("start and stop are idempotent", () async {
      final watcher = XFixesSelectionWatcher();
      await watcher.start();
      await watcher.start();
      await watcher.stop();
      await watcher.stop();
    }, skip: !_hasDisplay ? "requires a live X display" : null);

    test(
      "stop destroys the watcher's window and a later start works",
      () async {
        final client = _requireClient();
        try {
          final before = client.countRootChildren();
          final watcher = XFixesSelectionWatcher();
          final events = <bool>[];
          var subscription = watcher.onSelectionChanged.listen(events.add);
          try {
            await watcher.start();
            await _waitFor(
              () => events.isNotEmpty,
              const Duration(seconds: 10),
            );
            // The isolate's 1x1 event window is a child of the root.
            expect(client.countRootChildren(), before + 1);
            events.clear();
          } finally {
            await watcher.stop();
            await subscription.cancel();
          }
          // Stop asks the isolate to exit on its own, so its finally
          // block destroys the window: killing the isolate would leak
          // one window (and one display connection) per start.
          await _waitFor(
            () => client.countRootChildren() == before,
            const Duration(seconds: 5),
          );

          // The stream closed on stop, so a restart exposes a fresh one.
          final restarted = <bool>[];
          await watcher.start();
          subscription = watcher.onSelectionChanged.listen(restarted.add);
          try {
            await _waitFor(
              () => restarted.isNotEmpty,
              const Duration(seconds: 10),
            );
            restarted.clear();
            final window = client.createWindow();
            try {
              client.ownPrimarySilently(window);
              client.clearPrimary();
              await _waitFor(
                () => restarted.length >= 2,
                const Duration(seconds: 10),
              );
            } finally {
              client.destroyWindow(window);
            }
            expect(restarted, [true, false]);
          } finally {
            await watcher.stop();
            await subscription.cancel();
          }
          await _waitFor(
            () => client.countRootChildren() == before,
            const Duration(seconds: 5),
          );
        } finally {
          client.close();
        }
      },
      skip: !_hasDisplay ? "requires a live X display" : null,
    );
  });

  group("X11FocusedAppResolver", () {
    test("returns the WM_CLASS of the focused window", () async {
      const resolver = X11FocusedAppResolver();
      expect(X11FocusedAppResolver.isAvailable, isTrue);
      final client = _requireClient();
      final window = client.createWindow();
      try {
        client.focusWindowWithClass(window, "probe-app", "ProbeAppClass");
        await Future.delayed(const Duration(milliseconds: 200));
        expect(await resolver.getFocusedAppId(), "ProbeAppClass");
      } finally {
        client.destroyWindow(window);
        client.close();
      }
    }, skip: !_hasDisplay ? "requires a live X display" : null);

    test(
      "resolves the toplevel class when focus is on a child window",
      () async {
        const resolver = X11FocusedAppResolver();
        final client = _requireClient();
        final window = client.createWindow();
        final child = client.createChildWindow(window);
        try {
          // The toplevel carries the class; the child (the focused text
          // field, as in a real toolkit app) carries none.
          client.focusWindowWithClass(window, "probe-app", "ProbeAppClass");
          client.focusWindow(child);
          await Future.delayed(const Duration(milliseconds: 200));
          expect(await resolver.getFocusedAppId(), "ProbeAppClass");
        } finally {
          client.destroyWindow(child);
          client.destroyWindow(window);
          client.close();
        }
      },
      skip: !_hasDisplay ? "requires a live X display" : null,
    );

    test(
      "returns null for a window that no longer exists instead of crashing",
      () async {
        const resolver = X11FocusedAppResolver();
        final client = _requireClient();
        final window = client.createWindow();
        client.destroyWindow(window);
        client.flush();
        // The window is gone; resolving it must report null, not raise a
        // fatal X error.
        expect(await resolver.getAppIdForWindow(window), isNull);
        client.close();
      },
      skip: !_hasDisplay ? "requires a live X display" : null,
    );

    test("returns null when focus is the root window", () async {
      const resolver = X11FocusedAppResolver();
      final client = _requireClient();
      try {
        // Point focus at the root window via the test client.
        final setFocus = client._x11
            .lookupFunction<
              Int32 Function(Pointer<Void>, Uint64, Int32, Uint64),
              int Function(Pointer<Void>, int, int, int)
            >("XSetInputFocus");
        setFocus(client._display, 1, 1, 0);
        client.flush();
        await Future.delayed(const Duration(milliseconds: 200));
        expect(await resolver.getFocusedAppId(), isNull);
      } finally {
        client.close();
      }
    }, skip: !_hasDisplay ? "requires a live X display" : null);
  });

  group("X11ModifierState", () {
    test(
      "reports Control held and released",
      () async {
        expect(X11ModifierState.isAvailable, isTrue);
        expect(X11ModifierState.isHeld(X11Modifier.control), isFalse);
        final client = _requireClient();
        try {
          final keycode = client.pressKeyByKeysym(_keysymControlL);
          expect(keycode, isNotNull);
          try {
            await Future.delayed(const Duration(milliseconds: 300));
            expect(X11ModifierState.isHeld(X11Modifier.control), isTrue);
            expect(X11ModifierState.isHeld(X11Modifier.alt), isFalse);
            expect(X11ModifierState.isHeld(X11Modifier.shift), isFalse);
          } finally {
            client.releaseKey(keycode!);
          }
          await Future.delayed(const Duration(milliseconds: 200));
          expect(X11ModifierState.isHeld(X11Modifier.control), isFalse);
        } finally {
          client.close();
        }
      },
      skip: !_hasDisplay
          ? "requires a live X display"
          : !_TestXClient.hasXTest
          ? "requires XTest"
          : null,
    );

    test(
      "reports Alt held and released",
      () async {
        expect(X11ModifierState.isAvailable, isTrue);
        expect(X11ModifierState.isHeld(X11Modifier.alt), isFalse);
        final client = _requireClient();
        try {
          final keycode = client.pressKeyByKeysym(_keysymAltL);
          expect(keycode, isNotNull);
          try {
            await Future.delayed(const Duration(milliseconds: 300));
            expect(X11ModifierState.isHeld(X11Modifier.alt), isTrue);
            expect(X11ModifierState.isHeld(X11Modifier.control), isFalse);
            expect(X11ModifierState.isHeld(X11Modifier.shift), isFalse);
          } finally {
            client.releaseKey(keycode!);
          }
          await Future.delayed(const Duration(milliseconds: 200));
          expect(X11ModifierState.isHeld(X11Modifier.alt), isFalse);
        } finally {
          client.close();
        }
      },
      skip: !_hasDisplay
          ? "requires a live X display"
          : !_TestXClient.hasXTest
          ? "requires XTest"
          : null,
    );

    test(
      "reports Shift held and released",
      () async {
        expect(X11ModifierState.isAvailable, isTrue);
        expect(X11ModifierState.isHeld(X11Modifier.shift), isFalse);
        final client = _requireClient();
        try {
          final keycode = client.pressKeyByKeysym(_keysymShiftL);
          expect(keycode, isNotNull);
          try {
            await Future.delayed(const Duration(milliseconds: 300));
            expect(X11ModifierState.isHeld(X11Modifier.shift), isTrue);
            expect(X11ModifierState.isHeld(X11Modifier.control), isFalse);
            expect(X11ModifierState.isHeld(X11Modifier.alt), isFalse);
          } finally {
            client.releaseKey(keycode!);
          }
          await Future.delayed(const Duration(milliseconds: 200));
          expect(X11ModifierState.isHeld(X11Modifier.shift), isFalse);
        } finally {
          client.close();
        }
      },
      skip: !_hasDisplay
          ? "requires a live X display"
          : !_TestXClient.hasXTest
          ? "requires XTest"
          : null,
    );
  });
}

import "package:ciyue/services/desktop_selection_xtest.dart";
import "package:ciyue/services/selection_text_provider.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

/// Fake copy sender: records calls and, when [onSendCopy] is set, simulates
/// the target application copying its selection onto the clipboard.
class _FakeCopyKeySender implements CopyKeySender {
  int sendCalls = 0;
  bool result = true;
  void Function()? onSendCopy;

  @override
  Future<bool> sendCopy() async {
    sendCalls++;
    onSendCopy?.call();
    return result;
  }
}

/// Inner provider that always fails, proving the synthetic-copy provider
/// reports null instead of throwing.
class _ThrowingProvider implements SelectionTextProvider {
  @override
  Future<String?> getSelectedText() async {
    throw StateError("boom");
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // The fake clipboard behind the platform channel mock.
  String? fakeClipboard;
  Object? nextError;
  int getDataCalls = 0;
  Map<String, Object?>? Function(int callCount)? getDataOverride;

  setUp(() {
    fakeClipboard = null;
    nextError = null;
    getDataCalls = 0;
    getDataOverride = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case "Clipboard.getData":
          if (nextError != null) throw nextError!;
          getDataCalls++;
          final override = getDataOverride?.call(getDataCalls);
          if (override != null) return override;
          return fakeClipboard == null ? null : {"text": fakeClipboard};
        case "Clipboard.setData":
          fakeClipboard = (call.arguments as Map)["text"] as String?;
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group("ClipboardSelectionProvider", () {
    const provider = ClipboardSelectionProvider();

    test("returns the clipboard text trimmed", () async {
      fakeClipboard = "  hello  ";

      expect(await provider.getSelectedText(), "hello");
    });

    test("returns null when the clipboard is empty", () async {
      fakeClipboard = null;

      expect(await provider.getSelectedText(), isNull);
    });

    test("returns null when the clipboard holds only whitespace", () async {
      fakeClipboard = "   ";

      expect(await provider.getSelectedText(), isNull);
    });

    test("returns null instead of throwing when the channel fails", () async {
      nextError = PlatformException(code: "CLIPBOARD_ERROR");

      expect(await provider.getSelectedText(), isNull);
    });
  });

  group("SyntheticCopySelectionProvider", () {
    late _FakeCopyKeySender sender;

    setUp(() {
      sender = _FakeCopyKeySender();
    });

    SyntheticCopySelectionProvider provider({
      SelectionTextProvider? inner,
      Duration pollInterval = const Duration(milliseconds: 50),
      Duration pollTimeout = const Duration(milliseconds: 400),
    }) => SyntheticCopySelectionProvider(
      inner: inner ?? const ClipboardSelectionProvider(),
      copyKeySender: sender,
      pollInterval: pollInterval,
      pollTimeout: pollTimeout,
    );

    test("returns the new text when the clipboard changes", () async {
      fakeClipboard = "old text";
      sender.onSendCopy = () {
        fakeClipboard = "selected text";
      };

      expect(await provider().getSelectedText(), "selected text");
      expect(sender.sendCalls, 1);
      // The user's clipboard is put back even on success.
      expect(fakeClipboard, "old text");
    });

    test("returns the new text trimmed", () async {
      fakeClipboard = "old text";
      sender.onSendCopy = () {
        fakeClipboard = "  selected text  ";
      };

      expect(await provider().getSelectedText(), "selected text");
      expect(fakeClipboard, "old text");
    });

    test("returns null when the clipboard never changes", () async {
      fakeClipboard = "old text";

      expect(
        await provider(
          pollInterval: const Duration(milliseconds: 10),
          pollTimeout: const Duration(milliseconds: 100),
        ).getSelectedText(),
        isNull,
      );
      expect(sender.sendCalls, 1);
      expect(fakeClipboard, "old text");
    });

    test(
      "returns the text when the copy reproduces the previous clipboard text",
      () async {
        // The clipboard is cleared before the copy, so a copy that writes
        // back the same text is still recognised as a fresh copy.
        fakeClipboard = "same text";
        sender.onSendCopy = () {
          fakeClipboard = "same text";
        };

        expect(
          await provider(
            pollInterval: const Duration(milliseconds: 10),
            pollTimeout: const Duration(milliseconds: 100),
          ).getSelectedText(),
          "same text",
        );
        expect(fakeClipboard, "same text");
      },
    );

    test(
      "reports the rung unavailable when the sender reports failure",
      () async {
        fakeClipboard = "old text";
        sender.result = false;

        await expectLater(
          provider().getSelectedText(),
          throwsA(isA<SelectionUnavailableException>()),
        );
        expect(sender.sendCalls, 1);
        expect(fakeClipboard, "old text");
      },
    );

    test(
      "does not blank a clipboard that holds no text when the copy fails",
      () async {
        // No text on the clipboard (an image or a file, which text/plain
        // cannot represent): there is nothing to restore, so a failed copy
        // must leave the clipboard alone instead of writing empty text
        // over it.
        fakeClipboard = null;
        sender.result = false;

        await expectLater(
          provider().getSelectedText(),
          throwsA(isA<SelectionUnavailableException>()),
        );
        expect(fakeClipboard, isNull);
      },
    );

    test(
      "does not blank a clipboard that holds no text when the copy times out",
      () async {
        fakeClipboard = null;

        expect(
          await provider(
            pollInterval: const Duration(milliseconds: 10),
            pollTimeout: const Duration(milliseconds: 100),
          ).getSelectedText(),
          isNull,
        );
        expect(fakeClipboard, isNull);
      },
    );

    test("does not restore over text copied during the lookup", () async {
      fakeClipboard = "old text";
      sender.onSendCopy = () {
        fakeClipboard = "selected text";
      };
      // The restore's re-read (the third Clipboard.getData call: save,
      // poll, restore) sees text the user copied while the lookup was
      // running, so the restore must stand down.
      getDataOverride = (calls) =>
          calls >= 3 ? {"text": "user's new copy"} : null;

      expect(await provider().getSelectedText(), "selected text");
      expect(fakeClipboard, "selected text");
    });

    test("leaves the copied text on an empty clipboard after a copy", () async {
      // Nothing was saved (no text was on the clipboard), so there is
      // nothing to restore to; blanking it would destroy the text just
      // copied.
      fakeClipboard = null;
      sender.onSendCopy = () {
        fakeClipboard = "selected text";
      };

      expect(await provider().getSelectedText(), "selected text");
      expect(fakeClipboard, "selected text");
    });

    test(
      "reports the rung unavailable when the inner provider fails",
      () async {
        fakeClipboard = "old text";

        await expectLater(
          provider(inner: _ThrowingProvider()).getSelectedText(),
          throwsA(isA<SelectionUnavailableException>()),
        );
        expect(fakeClipboard, "old text");
      },
    );
  });

  group("UnsupportedCopyKeySender", () {
    test("never dispatches a keystroke", () async {
      expect(await const UnsupportedCopyKeySender().sendCopy(), isFalse);
    });
  });

  group("SelectionTextProviders.buildLadder", () {
    List<SelectionTextProvider> ladder({
      bool isLinux = false,
      bool isWindows = false,
      bool isMacOS = false,
      bool isWayland = false,
      bool xtestAvailable = false,
      SelectionTextProvider? x11Primary,
      SelectionTextProvider? atspi,
      SelectionTextProvider? nativeProvider,
      CopyKeySender? nativeCopySender,
    }) => SelectionTextProviders.buildLadder(
      isLinux: isLinux,
      isWindows: isWindows,
      isMacOS: isMacOS,
      isWayland: isWayland,
      xtestAvailable: xtestAvailable,
      x11Primary: x11Primary,
      atspi: atspi,
      nativeProvider: nativeProvider,
      nativeCopySender: nativeCopySender,
    );

    test("Linux X11 orders PRIMARY, AT-SPI2, synthetic copy, clipboard", () {
      final primary = _FakeSelectionProvider();
      final atspi = _FakeSelectionProvider();

      expect(
        ladder(
          isLinux: true,
          xtestAvailable: true,
          x11Primary: primary,
          atspi: atspi,
        ),
        [
          same(primary),
          same(atspi),
          isA<SyntheticCopySelectionProvider>(),
          isA<ClipboardSelectionProvider>(),
        ],
      );
    });

    test(
      "Linux X11 without lane providers is synthetic copy then clipboard",
      () {
        expect(ladder(isLinux: true, xtestAvailable: true), [
          isA<SyntheticCopySelectionProvider>(),
          isA<ClipboardSelectionProvider>(),
        ]);
      },
    );

    test("Linux X11 without XTest is clipboard only", () {
      expect(ladder(isLinux: true, xtestAvailable: false), [
        isA<ClipboardSelectionProvider>(),
      ]);
    });

    test("Linux Wayland is AT-SPI2 then clipboard, never synthetic copy", () {
      final atspi = _FakeSelectionProvider();

      expect(
        ladder(
          isLinux: true,
          isWayland: true,
          xtestAvailable: true,
          atspi: atspi,
        ),
        [same(atspi), isA<ClipboardSelectionProvider>()],
      );
    });

    test("Linux Wayland without AT-SPI2 is clipboard only", () {
      expect(ladder(isLinux: true, isWayland: true, xtestAvailable: true), [
        isA<ClipboardSelectionProvider>(),
      ]);
    });

    test("Windows orders native, synthetic copy, clipboard", () {
      final native = _FakeSelectionProvider();

      expect(
        ladder(
          isWindows: true,
          nativeProvider: native,
          nativeCopySender: _FakeCopyKeySender(),
        ),
        [
          same(native),
          isA<SyntheticCopySelectionProvider>(),
          isA<ClipboardSelectionProvider>(),
        ],
      );
    });

    test("Windows without a native sender is native then clipboard", () {
      final native = _FakeSelectionProvider();

      expect(ladder(isWindows: true, nativeProvider: native), [
        same(native),
        isA<ClipboardSelectionProvider>(),
      ]);
    });

    test("Windows without lane providers is clipboard only", () {
      expect(ladder(isWindows: true), [isA<ClipboardSelectionProvider>()]);
    });

    test("macOS prefers the native provider, else the clipboard", () {
      final native = _FakeSelectionProvider();

      expect(ladder(isMacOS: true, nativeProvider: native), [
        same(native),
        isA<ClipboardSelectionProvider>(),
      ]);
      expect(ladder(isMacOS: true), [isA<ClipboardSelectionProvider>()]);
    });
  });

  group("SelectionTextProviders.acquireRungs", () {
    test("falls through to the next rung when a rung is unavailable", () async {
      final unavailable = _FakeSelectionProvider(
        error: const SelectionUnavailableException("timed out"),
      );
      final next = _FakeSelectionProvider(text: "lane text");

      expect(
        await SelectionTextProviders.acquireRungs([unavailable, next]),
        "lane text",
      );
      expect(unavailable.calls, 1);
      expect(next.calls, 1);
    });

    test("falls through on an unexpected rung error too", () async {
      final broken = _FakeSelectionProvider(error: StateError("boom"));
      final next = _FakeSelectionProvider(text: "lane text");

      expect(
        await SelectionTextProviders.acquireRungs([broken, next]),
        "lane text",
      );
    });

    test("stops when a rung reports no selection", () async {
      final none = _FakeSelectionProvider(text: null);
      final clipboard = _FakeSelectionProvider(text: "stale clipboard text");

      expect(
        await SelectionTextProviders.acquireRungs([none, clipboard]),
        isNull,
      );
      expect(none.calls, 1);
      expect(clipboard.calls, 0);
    });

    test("returns null when every rung is unavailable", () async {
      final first = _FakeSelectionProvider(
        error: const SelectionUnavailableException("first"),
      );
      final second = _FakeSelectionProvider(
        error: const SelectionUnavailableException("second"),
      );

      expect(
        await SelectionTextProviders.acquireRungs([first, second]),
        isNull,
      );
    });
  });
}

/// Stand-in for a lane provider (X11 PRIMARY, AT-SPI2, native desktop).
class _FakeSelectionProvider implements SelectionTextProvider {
  _FakeSelectionProvider({this.text = "lane text", this.error});

  String? text;
  Object? error;
  int calls = 0;

  @override
  Future<String?> getSelectedText() async {
    calls++;
    if (error != null) throw error!;
    return text;
  }
}

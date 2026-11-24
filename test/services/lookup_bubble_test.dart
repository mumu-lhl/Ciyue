// ignore_for_file: invalid_use_of_internal_member
import "dart:async";

import "package:ciyue/services/lookup_bubble.dart";
import "package:ciyue/services/lookup_exclusion.dart";
import "package:ciyue/services/lookup_popup.dart";
import "package:ciyue/services/selection_watcher.dart";
import "package:flutter/src/widgets/_window.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

class _FakeWatcher implements SelectionWatcher {
  bool available = true;
  final _events = StreamController<bool>.broadcast();
  var startCalls = 0;
  var stopCalls = 0;

  void emit(bool appeared) => _events.add(appeared);

  @override
  bool get isAvailable => available;

  @override
  Stream<bool> get onSelectionChanged => _events.stream;

  @override
  Future<void> start() async {
    startCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

class _FakeResolver implements FocusedAppResolver {
  String? appId;

  @override
  Future<String?> getFocusedAppId() async => appId;
}

class _FakeBubbleBackend implements LookupBubbleWindowBackend {
  bool available = true;
  Offset? cursor = const Offset(100, 100);
  Rect? workArea = const Rect.fromLTWH(0, 0, 1920, 1080);
  Rect? cursorWorkArea;
  Size? windowSize;

  /// Sizes returned in order by successive [bubbleWindowSize] calls, when
  /// non-empty: lets a test report one size before the window is realized
  /// and another after it is shown.
  final List<Size?> windowSizeSequence = [];

  var createCalls = 0;
  var showCalls = 0;
  var hideCalls = 0;
  final positions = <Offset>[];

  @override
  bool get isAvailable => available;

  @override
  bool get isBubbleCreated => createCalls > 0;

  @override
  WindowController? get bubbleController => null;

  @override
  Future<void> createBubble() async {
    createCalls++;
  }

  @override
  Future<void> showBubble() async {
    showCalls++;
  }

  @override
  Future<void> hideBubble() async {
    hideCalls++;
  }

  @override
  Future<void> setBubblePosition(Offset position) async {
    positions.add(position);
  }

  @override
  Future<Offset?> cursorPosition() async => cursor;

  @override
  Future<Rect?> primaryWorkArea() async => workArea;

  @override
  Future<Rect?> workAreaAtCursor() async => cursorWorkArea;

  @override
  Future<Size?> bubbleWindowSize() async => windowSizeSequence.isNotEmpty
      ? windowSizeSequence.removeAt(0)
      : windowSize;
}

void main() {
  group("LookupBubbleService", () {
    late _FakeWatcher watcher;
    late _FakeResolver resolver;
    late _FakeBubbleBackend backend;
    late List<String> shownLookups;

    LookupBubbleService service({
      bool enabled = true,
      String trigger = "selection",
      String modifier = "control",
      List<String> excludedApps = const [],
      Future<String?> Function()? acquireText,
      Future<bool> Function(String modifier)? isModifierHeld,
      Future<bool> Function()? isDoubleClickSelection,
      Duration? bubbleDwell,
      bool Function(String? appId)? isOwnApp,
      bool Function(String? appId, List<String> patterns)? isExcluded,
    }) {
      return LookupBubbleService(
        enabled: enabled,
        trigger: trigger,
        modifier: modifier,
        excludedApps: excludedApps,
        watcher: watcher,
        focusedAppResolver: resolver,
        acquireText: acquireText ?? () async => "selected text",
        showLookup: (text) async {
          shownLookups.add(text);
        },
        bubbleBackend: backend,
        isOwnApp: isOwnApp,
        isExcluded: isExcluded,
        isModifierHeld: isModifierHeld,
        isDoubleClickSelection: isDoubleClickSelection,
        bubbleDwell: bubbleDwell ?? const Duration(seconds: 30),
      );
    }

    Future<void> start(LookupBubbleService bubble) async {
      await bubble.start();
      // Let the watcher subscription attach before emitting.
      await Future<void>.delayed(Duration.zero);
    }

    Future<void> settle() async {
      // The handler awaits the resolver, the text and the backend in turn;
      // flush enough event-loop turns for a full handling to land.
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    setUp(() {
      watcher = _FakeWatcher();
      resolver = _FakeResolver();
      // A foreign app by default: an unknown focused app must not show
      // the bubble (fail closed), so tests that expect a bubble need a
      // known foreign id here.
      resolver.appId = "com.example.editor";
      backend = _FakeBubbleBackend();
      shownLookups = <String>[];
    });

    test("watcher true shows the bubble with the acquired text", () async {
      final bubble = service();
      await start(bubble);

      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bubble.isVisible, isTrue);
      expect(bubble.currentText.value, "selected text");
      expect(backend.createCalls, 1);
      expect(backend.showCalls, 1);
      expect(backend.positions, [const Offset(112, 116)]);
      await bubble.stop();
    });

    test("empty acquisition hides the bubble", () async {
      final bubble = service(acquireText: () async => "   ");
      await start(bubble);

      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bubble.isVisible, isFalse);
      expect(backend.showCalls, 0);
      await bubble.stop();
    });

    test("null acquisition hides the bubble", () async {
      final bubble = service(acquireText: () async => null);
      await start(bubble);

      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bubble.isVisible, isFalse);
      expect(backend.showCalls, 0);
      await bubble.stop();
    });

    test("excluded app hides the bubble", () async {
      resolver.appId = "com.example.game";
      final bubble = service(
        excludedApps: const ["game"],
        isExcluded: LookupExclusionService.isExcluded,
      );
      await start(bubble);

      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bubble.isVisible, isFalse);
      expect(backend.showCalls, 0);
      await bubble.stop();
    });

    test("own app hides the bubble", () async {
      // The real WM_CLASS of Ciyue's own window (see X11FocusedAppResolver).
      resolver.appId = "Org.eu.mumulhl.ciyue";
      final bubble = service(isOwnApp: LookupExclusionService.isOwnApp);
      await start(bubble);

      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bubble.isVisible, isFalse);
      expect(backend.showCalls, 0);
      await bubble.stop();
    });

    test("modifier trigger ignores the selection when not held", () async {
      final bubble = service(
        trigger: "modifier",
        isModifierHeld: (_) async => false,
      );
      await start(bubble);

      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bubble.isVisible, isFalse);
      expect(backend.showCalls, 0);
      await bubble.stop();
    });

    test("modifier trigger shows the bubble when held", () async {
      final bubble = service(
        trigger: "modifier",
        modifier: "control",
        isModifierHeld: (modifier) async => modifier == "control",
      );
      await start(bubble);

      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bubble.isVisible, isTrue);
      expect(bubble.currentText.value, "selected text");
      await bubble.stop();
    });

    test("modifier trigger with no helper ignores the selection", () async {
      final bubble = service(trigger: "modifier", isModifierHeld: null);
      await start(bubble);

      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bubble.isVisible, isFalse);
      expect(backend.showCalls, 0);
      await bubble.stop();
    });

    test("reconfigure keeps the same instance live on a new watcher", () async {
      // Regression: preference changes used to replace the service
      // instance, leaving the bubble host listening to a dead service
      // whose currentText never changed — the native window was created
      // but no content was ever mounted into it. Reconfigure must update
      // the same instance in place.
      final bubble = service();
      await start(bubble);

      final replacement = _FakeWatcher();
      await bubble.reconfigure(
        enabled: true,
        trigger: "selection",
        modifier: "control",
        excludedApps: const [],
        watcher: replacement,
        focusedAppResolver: resolver,
        isModifierHeld: null,
      );

      // The old watcher is released: its events no longer show anything.
      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bubble.isVisible, isFalse);

      // The new watcher drives the same instance.
      replacement.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bubble.isVisible, isTrue);
      expect(bubble.currentText.value, "selected text");
      await bubble.stop();
    });

    test("watcher false hides the bubble", () async {
      final bubble = service();
      await start(bubble);
      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bubble.isVisible, isTrue);

      watcher.emit(false);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bubble.isVisible, isFalse);
      expect(backend.hideCalls, greaterThanOrEqualTo(1));
      await bubble.stop();
    });

    test(
      "openLookup shows the popup for the bubble text and hides it",
      () async {
        final bubble = service();
        await start(bubble);
        watcher.emit(true);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(bubble.isVisible, isTrue);

        await bubble.openLookup();

        expect(shownLookups, ["selected text"]);
        expect(bubble.isVisible, isFalse);
        await bubble.stop();
      },
    );

    test("start does nothing when disabled", () async {
      final bubble = service(enabled: false);

      await bubble.start();

      expect(bubble.isRunning, isFalse);
      expect(watcher.startCalls, 0);
      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      expect(bubble.isVisible, isFalse);
    });

    test("start does nothing when the watcher is unavailable", () async {
      watcher.available = false;
      final bubble = service();

      await bubble.start();

      expect(bubble.isRunning, isFalse);
      expect(watcher.startCalls, 0);
    });

    test("start does nothing without a watcher", () async {
      final noWatcher = LookupBubbleService(
        enabled: true,
        bubbleBackend: backend,
      );

      await noWatcher.start();

      expect(noWatcher.isRunning, isFalse);
    });

    test("stop hides the bubble and stops the watcher", () async {
      final bubble = service();
      await start(bubble);
      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bubble.isVisible, isTrue);

      await bubble.stop();

      expect(bubble.isVisible, isFalse);
      expect(bubble.isRunning, isFalse);
      expect(watcher.stopCalls, 1);
    });

    test("a throwing acquire never throws out of the handler", () async {
      final bubble = service(acquireText: () async => throw StateError("boom"));
      await start(bubble);

      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bubble.isVisible, isFalse);
      expect(backend.showCalls, 0);
      await bubble.stop();
    });

    test("bubble position clamps inside the work area", () async {
      backend.cursor = const Offset(1900, 1000);
      final bubble = service();
      await start(bubble);

      watcher.emit(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Cursor (1900, 1000) + offset (12, 16) = (1912, 1016); x clamps to
      // 1920 - 48, y stays inside at 1016.
      expect(backend.positions, [const Offset(1920 - 48, 1016)]);
      await bubble.stop();
    });

    test("unknown focused app hides the bubble", () async {
      resolver.appId = null;
      final bubble = service();
      await start(bubble);

      watcher.emit(true);
      await settle();

      expect(bubble.isVisible, isFalse);
      expect(backend.showCalls, 0);
      await bubble.stop();
    });

    test("no focused-app resolver hides the bubble", () async {
      final bubble = LookupBubbleService(
        enabled: true,
        watcher: watcher,
        acquireText: () async => "selected text",
        showLookup: (text) async {
          shownLookups.add(text);
        },
        bubbleBackend: backend,
      );
      await start(bubble);

      watcher.emit(true);
      await settle();

      expect(bubble.isVisible, isFalse);
      expect(backend.showCalls, 0);
      await bubble.stop();
    });

    test("a slow event cannot overwrite a newer selection", () async {
      final firstAcquired = Completer<String?>();
      var acquireCalls = 0;
      final bubble = service(
        acquireText: () async {
          acquireCalls++;
          if (acquireCalls == 1) return firstAcquired.future;
          return "second text";
        },
      );
      await start(bubble);

      watcher.emit(true);
      await settle();
      // The first event is still waiting on its text; the second event
      // arrives and must win once the first finally completes.
      watcher.emit(true);
      await settle();
      firstAcquired.complete("first text");
      await settle();

      expect(bubble.currentText.value, "second text");
      await bubble.stop();
    });

    test("a slow event cannot show after a newer clear", () async {
      final acquired = Completer<String?>();
      final bubble = service(acquireText: () => acquired.future);
      await start(bubble);

      watcher.emit(true);
      await settle();
      watcher.emit(false);
      acquired.complete("stale text");
      await settle();

      expect(bubble.isVisible, isFalse);
      expect(bubble.currentText.value, isNull);
      await bubble.stop();
    });

    test("doubleClick trigger never fires without a click reporter", () async {
      final bubble = service(trigger: "doubleClick");
      await start(bubble);

      watcher.emit(true);
      await settle();

      expect(bubble.isVisible, isFalse);
      expect(backend.showCalls, 0);
      await bubble.stop();
    });

    test("doubleClick trigger shows only for reported double-clicks", () async {
      var isDoubleClick = false;
      final bubble = service(
        trigger: "doubleClick",
        isDoubleClickSelection: () async => isDoubleClick,
      );
      await start(bubble);

      watcher.emit(true);
      await settle();
      expect(bubble.isVisible, isFalse);

      isDoubleClick = true;
      watcher.emit(true);
      await settle();
      expect(bubble.isVisible, isTrue);
      expect(bubble.currentText.value, "selected text");
      await bubble.stop();
    });

    test("openLookup keeps a newer selection's text", () async {
      final popupOpened = Completer<void>();
      var acquireCalls = 0;
      final bubble = LookupBubbleService(
        enabled: true,
        watcher: watcher,
        focusedAppResolver: resolver,
        acquireText: () async {
          acquireCalls++;
          return acquireCalls == 1 ? "first text" : "second text";
        },
        showLookup: (text) async {
          shownLookups.add(text);
          await popupOpened.future;
        },
        bubbleBackend: backend,
      );
      await start(bubble);
      watcher.emit(true);
      await settle();
      expect(bubble.currentText.value, "first text");

      final opening = bubble.openLookup();
      watcher.emit(true);
      await settle();
      expect(bubble.currentText.value, "second text");
      popupOpened.complete();
      await opening;

      expect(shownLookups, ["first text"]);
      expect(bubble.currentText.value, "second text");
      expect(bubble.isVisible, isTrue);
      await bubble.stop();
    });

    test("bubble hides itself after the dwell timeout", () async {
      final bubble = service(bubbleDwell: const Duration(milliseconds: 100));
      await start(bubble);
      watcher.emit(true);
      await settle();
      expect(bubble.isVisible, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(bubble.isVisible, isFalse);
      expect(backend.hideCalls, greaterThanOrEqualTo(1));
      await bubble.stop();
    });

    test("bubble position uses the cursor display's work area", () async {
      backend.cursor = const Offset(2000, 100);
      backend.cursorWorkArea = const Rect.fromLTWH(1920, 0, 1920, 1080);
      final bubble = service();
      await start(bubble);

      watcher.emit(true);
      await settle();

      expect(backend.positions, [const Offset(2012, 116)]);
      await bubble.stop();
    });

    test("bubble position clamps by the realized window size", () async {
      backend.cursor = const Offset(1900, 1000);
      backend.windowSize = const Size(264, 264);
      final bubble = service();
      await start(bubble);

      watcher.emit(true);
      await settle();

      // A 264x264 window clamps to 1920 - 264 on x and 1080 - 264 on y,
      // not to the 48x48 preferred size on either axis.
      expect(backend.positions, [const Offset(1920 - 264, 1080 - 264)]);
      await bubble.stop();
    });

    test("bubble re-positions once the realized size is known", () async {
      backend.cursor = const Offset(1900, 1000);
      backend.windowSizeSequence.addAll([
        const Size(48, 48),
        const Size(264, 264),
      ]);
      final bubble = service();
      await start(bubble);

      watcher.emit(true);
      await settle();

      // First positioned by the pre-show 48x48 read, then re-positioned
      // by the 264x264 size read after the window is shown.
      expect(backend.positions, [
        const Offset(1920 - 48, 1016),
        const Offset(1920 - 264, 1080 - 264),
      ]);
      expect(bubble.isVisible, isTrue);
      await bubble.stop();
    });
  });
}

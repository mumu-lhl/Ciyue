// ignore_for_file: invalid_use_of_internal_member

import "dart:async";

import "package:ciyue/services/lookup_mode.dart";
import "package:ciyue/services/lookup_popup.dart";
import "package:flutter/src/widgets/_window.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

class FakeLookupPopupWindowBackend implements LookupPopupWindowBackend {
  FakeLookupPopupWindowBackend({
    this.available = true,
    this.cursor = const Offset(100, 100),
    this.workArea = const Rect.fromLTWH(0, 0, 1920, 1080),
    this.throwOnShow = false,
    this.showResult = true,
  });

  bool available;
  Offset? cursor;
  Rect? workArea;
  Rect? cursorWorkArea;
  bool throwOnShow;
  bool showResult;
  Completer<void>? showGate;

  var createCalls = 0;
  var showCalls = 0;
  var hideCalls = 0;
  final positions = <Offset>[];

  @override
  bool get isAvailable => available;

  @override
  bool get isCreated => createCalls > 0;

  @override
  WindowController? get controller => null;

  @override
  Future<void> create() async {
    createCalls++;
  }

  @override
  Future<bool> show() async {
    if (throwOnShow) throw StateError("show failed");
    showCalls++;
    final gate = showGate;
    if (gate != null) await gate.future;
    return showResult;
  }

  @override
  Future<void> hide() async {
    hideCalls++;
  }

  @override
  Future<void> setPosition(Offset position) async {
    positions.add(position);
  }

  @override
  Future<void> setFrameless(bool frameless) async {}

  @override
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {}

  @override
  Future<Offset?> cursorPosition() async => cursor;

  @override
  Future<Rect?> primaryWorkArea() async => workArea;

  @override
  Future<Rect?> workAreaAtCursor() async => cursorWorkArea;

  @override
  void Function()? onFocusLost;
}

LookupPopupService serviceWith({
  FakeLookupPopupWindowBackend? backend,
  Future<String?> Function()? acquire,
  void Function(String text)? fallbackNavigate,
  Future<void> Function()? onNoTextSelected,
}) {
  final navigated = <String>[];
  return LookupPopupService(
    windowBackend: backend ?? FakeLookupPopupWindowBackend(),
    acquireSelectionText: acquire ?? () async => null,
    fallbackNavigate: fallbackNavigate ?? navigated.add,
    onNoTextSelected: onNoTextSelected ?? () async {},
  );
}

void main() {
  test(
    "showLookup with text publishes the request and shows the window",
    () async {
      final backend = FakeLookupPopupWindowBackend();
      final service = serviceWith(backend: backend);

      await service.showLookup("apple");

      // Requests carry a per-show sequence, so compare the payload rather
      // than the whole value.
      expect(service.currentRequest.value?.text, "apple");
      expect(service.currentRequest.value?.mode, LookupMode.lookup);
      expect(service.isVisible, isTrue);
      expect(backend.createCalls, 1);
      expect(backend.showCalls, 1);
      expect(backend.positions, [const Offset(112, 116)]);
      final position = backend.positions.single;
      expect(
        Rect.fromLTWH(
          position.dx,
          position.dy,
          LookupPopupService.popupSize.width,
          LookupPopupService.popupSize.height,
        ),
        withinRect(backend.workArea!),
      );
    },
  );

  test("showLookup with a long text decides translate mode", () async {
    final backend = FakeLookupPopupWindowBackend();
    final service = serviceWith(backend: backend);
    const text = "one two three four five six seven";

    await service.showLookup(text);

    expect(service.currentRequest.value?.text, text);
    expect(service.currentRequest.value?.mode, LookupMode.translate);
    expect(service.isVisible, isTrue);
  });

  test("showLookup with explicit text never acquires the selection", () async {
    var acquireCalls = 0;
    final service = serviceWith(
      acquire: () async {
        acquireCalls++;
        return "acquired";
      },
    );

    await service.showLookup("given");

    expect(acquireCalls, 0);
    expect(service.currentRequest.value?.text, "given");
  });

  test("showLookup with null text acquires and trims the selection", () async {
    final service = serviceWith(acquire: () async => "  banana  ");

    await service.showLookup(null);

    expect(service.currentRequest.value?.text, "banana");
    expect(service.currentRequest.value?.mode, LookupMode.lookup);
  });

  test("showLookup with no text anywhere toasts and opens nothing", () async {
    final backend = FakeLookupPopupWindowBackend();
    var toastCalls = 0;
    final service = serviceWith(
      backend: backend,
      acquire: () async => null,
      onNoTextSelected: () async {
        toastCalls++;
      },
    );

    await service.showLookup(null);
    await service.showLookup("   ");

    expect(toastCalls, 2);
    expect(service.currentRequest.value, isNull);
    expect(service.isVisible, isFalse);
    expect(backend.createCalls, 0);
    expect(backend.showCalls, 0);
  });

  test(
    "hide clears the request, hides the window, and is idempotent",
    () async {
      final backend = FakeLookupPopupWindowBackend();
      final service = serviceWith(backend: backend);
      await service.showLookup("apple");

      service.hide();
      service.hide();

      expect(service.currentRequest.value, isNull);
      expect(service.isVisible, isFalse);
      expect(backend.hideCalls, 2);
    },
  );

  test("showLookup without windowing falls back to the main window", () async {
    final backend = FakeLookupPopupWindowBackend(available: false);
    final navigated = <String>[];
    final service = serviceWith(
      backend: backend,
      fallbackNavigate: navigated.add,
    );

    await service.showLookup("apple");

    expect(navigated, ["apple"]);
    expect(service.currentRequest.value, isNull);
    expect(service.isVisible, isFalse);
    expect(backend.createCalls, 0);
    expect(backend.showCalls, 0);
  });

  test("showLookup falls back to the main window when showing fails", () async {
    final backend = FakeLookupPopupWindowBackend(throwOnShow: true);
    final navigated = <String>[];
    final service = serviceWith(
      backend: backend,
      fallbackNavigate: navigated.add,
    );

    await service.showLookup("apple");

    expect(navigated, ["apple"]);
    expect(service.currentRequest.value, isNull);
    expect(service.isVisible, isFalse);
  });

  test("cursor position is centred when the cursor cannot be read", () async {
    final backend = FakeLookupPopupWindowBackend(cursor: null);
    final service = serviceWith(backend: backend);

    await service.showLookup("apple");

    expect(backend.positions, [
      const Offset((1920 - 440) / 2, (1080 - 560) / 2),
    ]);
    expect(service.isVisible, isTrue);
  });

  test("no position is set when the display cannot be read", () async {
    final backend = FakeLookupPopupWindowBackend(workArea: null);
    final service = serviceWith(backend: backend);

    await service.showLookup("apple");

    expect(backend.positions, isEmpty);
    expect(service.isVisible, isTrue);
  });

  group("focus loss", () {
    test("hides the popup when it loses focus while visible", () async {
      final backend = FakeLookupPopupWindowBackend();
      final service = serviceWith(backend: backend);
      await service.showLookup("apple");

      backend.onFocusLost?.call();

      expect(service.isVisible, isFalse);
      expect(service.currentRequest.value, isNull);
      expect(backend.hideCalls, 1);
    });

    test("does nothing when focus is lost while hidden", () async {
      final backend = FakeLookupPopupWindowBackend();
      final service = serviceWith(backend: backend);

      backend.onFocusLost?.call();

      expect(service.isVisible, isFalse);
      expect(backend.hideCalls, 0);
    });
  });

  group("clampPopupPosition", () {
    const workArea = Rect.fromLTWH(0, 0, 1920, 1080);
    const popupSize = LookupPopupService.popupSize;

    test("cursor near the top-left keeps the cursor offset", () {
      expect(
        LookupPopupService.clampPopupPosition(
          cursor: const Offset(100, 100),
          popupSize: popupSize,
          workArea: workArea,
        ),
        const Offset(112, 116),
      );
    });

    test("cursor near the bottom-right clamps inside the work area", () {
      expect(
        LookupPopupService.clampPopupPosition(
          cursor: const Offset(1900, 1000),
          popupSize: popupSize,
          workArea: workArea,
        ),
        const Offset(1920 - 440, 1080 - 560),
      );
    });

    test("cursor past the right edge clamps the x only", () {
      expect(
        LookupPopupService.clampPopupPosition(
          cursor: const Offset(2000, 100),
          popupSize: popupSize,
          workArea: workArea,
        ),
        const Offset(1920 - 440, 116),
      );
    });

    test("work area with an offset origin is honoured", () {
      expect(
        LookupPopupService.clampPopupPosition(
          cursor: const Offset(100, 100),
          popupSize: popupSize,
          workArea: const Rect.fromLTWH(1920, 0, 1920, 1080),
        ),
        const Offset(1920, 116),
      );
    });

    test("work area smaller than the popup starts at its edge", () {
      expect(
        LookupPopupService.clampPopupPosition(
          cursor: const Offset(100, 100),
          popupSize: popupSize,
          workArea: const Rect.fromLTWH(50, 60, 200, 200),
        ),
        const Offset(50, 60),
      );
    });
  });

  test("centerPopupPosition centres inside the work area", () {
    expect(
      LookupPopupService.centerPopupPosition(
        popupSize: LookupPopupService.popupSize,
        workArea: const Rect.fromLTWH(100, 50, 1000, 800),
      ),
      const Offset(100 + (1000 - 440) / 2, 50 + (800 - 560) / 2),
    );
  });

  test("showLookup reports false when the window never shows", () async {
    final backend = FakeLookupPopupWindowBackend(showResult: false);
    final navigated = <String>[];
    final service = serviceWith(
      backend: backend,
      fallbackNavigate: navigated.add,
    );

    await service.showLookup("apple");

    expect(navigated, ["apple"]);
    expect(service.currentRequest.value, isNull);
    expect(service.isVisible, isFalse);
  });

  test("looking up the same text twice notifies listeners twice", () async {
    final backend = FakeLookupPopupWindowBackend();
    final service = serviceWith(backend: backend);
    var notifications = 0;
    service.currentRequest.addListener(() {
      notifications++;
    });

    await service.showLookup("apple");
    await service.showLookup("apple");

    expect(notifications, 2);
    expect(service.currentRequest.value?.text, "apple");
    expect(service.isVisible, isTrue);
  });

  test("hide during an in-flight show keeps the popup closed", () async {
    final backend = FakeLookupPopupWindowBackend();
    backend.showGate = Completer<void>();
    final service = serviceWith(backend: backend);

    final showing = service.showLookup("apple");
    // Let the show reach the gated backend show.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(backend.showCalls, 1);

    service.hide();
    backend.showGate!.complete();
    await showing;

    expect(service.isVisible, isFalse);
    expect(service.currentRequest.value, isNull);
  });

  test("show failure falls back to the acquired query, not nothing", () async {
    final backend = FakeLookupPopupWindowBackend(throwOnShow: true);
    final navigated = <String>[];
    final service = serviceWith(
      backend: backend,
      acquire: () async => "banana",
      fallbackNavigate: navigated.add,
    );

    await service.showLookup(null);

    expect(navigated, ["banana"]);
    expect(service.isVisible, isFalse);
  });

  test("popup position uses the cursor display's work area", () async {
    final backend = FakeLookupPopupWindowBackend(
      cursor: const Offset(2000, 100),
    );
    backend.cursorWorkArea = const Rect.fromLTWH(1920, 0, 1920, 1080);
    final service = serviceWith(backend: backend);

    await service.showLookup("apple");

    expect(backend.positions, [const Offset(2012, 116)]);
    expect(service.isVisible, isTrue);
  });

  test("requests for the same text are never equal", () {
    const first = LookupPopupRequest(
      text: "apple",
      mode: LookupMode.lookup,
      sequence: 1,
    );
    const second = LookupPopupRequest(
      text: "apple",
      mode: LookupMode.lookup,
      sequence: 2,
    );

    expect(first, isNot(second));
    expect(first.hashCode, isNot(second.hashCode));
  });
}

/// Matches when every point of [rect] lies inside [outer].
Matcher withinRect(Rect outer) => _WithinRect(outer);

class _WithinRect extends Matcher {
  _WithinRect(this.outer);

  final Rect outer;

  @override
  Description describe(Description description) =>
      description.add("a rect inside $outer");

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! Rect) return false;
    return outer.contains(item.topLeft) && outer.contains(item.bottomRight);
  }
}

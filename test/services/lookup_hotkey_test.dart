import "dart:io";

import "package:ciyue/services/lookup_hotkey.dart";
import "package:ciyue/utils.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hotkey_manager/hotkey_manager.dart";

void main() {
  group("LookupHotkeyService.isSupported", () {
    test("is desktop and not Wayland, whatever this session is", () {
      // The check is definitional: no assertion here about which session
      // the test itself runs in, so it holds on Wayland CI too.
      expect(
        LookupHotkeyService.isSupported,
        isDesktop() && !isWaylandSession(),
      );
    });
  });

  group("LookupHotkeyService.hotKey", () {
    test("is C with Ctrl+Alt on Linux/Windows, Cmd+Option on macOS", () {
      final hotKey = LookupHotkeyService.hotKey;
      expect(hotKey.key, PhysicalKeyboardKey.keyC);
      expect(hotKey.scope, HotKeyScope.system);
      if (Platform.isMacOS) {
        expect(hotKey.modifiers, [HotKeyModifier.meta, HotKeyModifier.alt]);
      } else {
        expect(hotKey.modifiers, [HotKeyModifier.control, HotKeyModifier.alt]);
      }
    });

    test("is one stable instance, so per-key unregister can find it", () {
      expect(
        identical(LookupHotkeyService.hotKey, LookupHotkeyService.hotKey),
        isTrue,
      );
    });
  });

  group("LookupHotkeyService.apply", () {
    test("apply(false) when never applied is a no-op returning true", () async {
      expect(await LookupHotkeyService.apply(false), isTrue);
      expect(LookupHotkeyService.isApplied, isFalse);
    });

    test("apply(false) twice in a row is idempotent", () async {
      expect(await LookupHotkeyService.apply(false), isTrue);
      expect(await LookupHotkeyService.apply(false), isTrue);
      expect(LookupHotkeyService.isApplied, isFalse);
    });

    test("apply(true) fails without a plugin registrant, and apply(false) undoes it", () async {
      // No plugin registrant in a unit test, so the native registration is
      // expected to fail; apply must report that instead of throwing. If
      // the platform ever does register, the undo below still holds.
      final result = await LookupHotkeyService.apply(true);
      expect(result, isFalse);
      expect(LookupHotkeyService.isApplied, isFalse);
      expect(await LookupHotkeyService.apply(false), isTrue);
      expect(LookupHotkeyService.isApplied, isFalse);
    });
  });

  group("LookupHotkeyService.handleHotKey", () {
    late List<String?> shown;
    late Future<String?> Function() savedAcquire;
    late Future<void> Function(String?) savedShow;

    setUp(() {
      shown = <String?>[];
      savedAcquire = LookupHotkeyService.acquireSelectionText;
      savedShow = LookupHotkeyService.showLookup;
      LookupHotkeyService.showLookup = (text) async {
        shown.add(text);
      };
    });

    tearDown(() {
      LookupHotkeyService.acquireSelectionText = savedAcquire;
      LookupHotkeyService.showLookup = savedShow;
    });

    test("shows the popup with the acquired text", () async {
      LookupHotkeyService.acquireSelectionText = () async => "hello";
      await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
      expect(shown, ["hello"]);
    });

    test("opens nothing when nothing is selected", () async {
      LookupHotkeyService.acquireSelectionText = () async => null;
      await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
      expect(shown, isEmpty);
    });

    test("opens nothing for whitespace-only text", () async {
      LookupHotkeyService.acquireSelectionText = () async => "   \n  ";
      await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
      expect(shown, isEmpty);
    });

    test("never throws when acquisition fails", () async {
      LookupHotkeyService.acquireSelectionText = () async {
        throw StateError("clipboard unavailable");
      };
      await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
      expect(shown, isEmpty);
    });

    test("never throws when showing the popup fails", () async {
      LookupHotkeyService.acquireSelectionText = () async => "hello";
      LookupHotkeyService.showLookup = (text) async {
        throw StateError("no window");
      };
      await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
    });
  });
}

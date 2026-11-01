import "package:ciyue/ui/pages/main/home/shortcuts.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  group("bridgeShortcutActivator", () {
    test("reads a control shortcut out of the bridge message", () {
      final activator = bridgeShortcutActivator(
        '{"code":"KeyT","key":"t","ctrl":true,"alt":false,"shift":false,"meta":false}',
      );

      expect(activator, isNotNull);
      expect(activator!.trigger, LogicalKeyboardKey.keyT);
      expect(activator.control, isTrue);
      expect(activator.alt, isFalse);
      expect(activator.shift, isFalse);
      expect(activator.meta, isFalse);
    });

    test("reads a control and shift shortcut", () {
      final activator = bridgeShortcutActivator(
        '{"code":"Tab","key":"Tab","ctrl":true,"alt":false,"shift":true,"meta":false}',
      );

      expect(activator, isNotNull);
      expect(activator!.trigger, LogicalKeyboardKey.tab);
      expect(activator.control, isTrue);
      expect(activator.shift, isTrue);
    });

    test("reads Escape without modifiers", () {
      final activator = bridgeShortcutActivator(
        '{"code":"Escape","key":"Escape","ctrl":false,"alt":false,"shift":false,"meta":false}',
      );

      expect(activator, isNotNull);
      expect(activator!.trigger, LogicalKeyboardKey.escape);
      expect(activator.control, isFalse);
    });

    test("ignores a key the home page does not bind", () {
      expect(bridgeShortcutActivator('{"code":"KeyC","ctrl":true}'), isNull);
    });

    test("ignores a malformed message", () {
      expect(bridgeShortcutActivator("not json"), isNull);
    });
  });

  group("shortcutActionFor", () {
    test("finds a binding whose activator has no value equality", () {
      var called = false;
      final bindings = <SingleActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () {
          called = true;
        },
      };
      final activator = bridgeShortcutActivator(
        '{"code":"KeyT","key":"t","ctrl":true,"alt":false,"shift":false,"meta":false}',
      )!;

      shortcutActionFor(bindings, activator)!.call();

      expect(called, isTrue);
    });

    test("does not match a different modifier", () {
      final bindings = <SingleActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () {},
      };
      final activator = bridgeShortcutActivator(
        '{"code":"KeyT","key":"t","ctrl":true,"alt":false,"shift":true,"meta":false}',
      )!;

      expect(shortcutActionFor(bindings, activator), isNull);
    });
  });
}

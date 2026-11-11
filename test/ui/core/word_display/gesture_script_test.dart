import "package:ciyue/ui/core/word_display/gesture_script.dart";
import "package:ciyue/ui/core/word_display/webview_widgets.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("gestureScript", () {
    final script = gestureScript();

    test("forwards gestures through the key bridge", () {
      expect(script, contains("'ciyueKey', 'Gesture'"));
      expect(script, contains("send('rocker', 1)"));
      expect(script, contains("send('wheel', e.deltaY > 0 ? 1 : -1)"));
    });

    test("suppresses the menu only while the left button is down", () {
      expect(script, contains("if (e.ctrlKey) return;"));
    });

    test(
      "treats a contextmenu as a rocker only when the right button is in",
      () {
        // A touch/pen long press fires contextmenu with button 0; only a real
        // right press (button 2 or a tracked right-down) may start a rocker.
        expect(script, contains("(e.button === 2 || rightDown)"));
      },
    );

    test("resets the button state when the window loses focus", () {
      expect(script, contains("window.addEventListener('blur'"));
    });

    test("falls back to contextmenu without sending the rocker twice", () {
      expect(script, contains("sendRocker();"));
      expect(script, contains("if (rockerSent) return;"));
      expect(script, contains("rockerSent = false;"));
    });

    test("exports a rocker hook for the Windows pointer edge", () {
      expect(script, contains("window.ciyueRocker = function ()"));
      expect(script, contains("if (leftDown) sendRocker();"));
      // Windows runs with the bitmask fallback off, so the hook must not
      // depend on it.
      final windows = gestureScript(bitmaskFallback: false);
      expect(windows, contains("window.ciyueRocker = function ()"));
      expect(windows, isNot(contains("(e.buttons & 2) !== 0")));
    });

    test("falls back to the move-event button bitmask", () {
      expect(script, contains("document.addEventListener('mousemove'"));
      expect(script, contains("(e.buttons & 2) !== 0"));
    });

    test("omits the bitmask fallback where the engine reports the button", () {
      // WebView2 reports the right button as a real mousedown and keeps the
      // right bit set after the app's context menu opens, so reading the
      // bitmask would turn a later left click into a false rocker.
      final windows = gestureScript(bitmaskFallback: false);
      expect(windows, isNot(contains("(e.buttons & 2) !== 0")));
      expect(windows, isNot(contains("addEventListener('mousemove'")));
    });

    test("uses a non-passive wheel listener and throttles repeat events", () {
      expect(script, contains("{ capture: true, passive: false }"));
      expect(script, contains("if (now - lastWheelAt < 80) return;"));
      expect(script, contains("if (!leftDown) return;"));
    });

    test("swallows the click that follows a gesture", () {
      expect(script, contains("document.addEventListener('click'"));
      expect(script, isNot(contains("middleDown")));
    });
  });

  group("dictionaryUserScripts", () {
    test("leaves the gesture script out by default", () {
      final scripts = dictionaryUserScripts();
      expect(scripts, hasLength(7));
      expect(scripts.any((s) => s.source.contains("'Gesture'")), isFalse);
    });

    test("injects the gesture script on the desktop", () {
      final scripts = dictionaryUserScripts(isDesktop: true);
      expect(scripts, hasLength(8));
      expect(scripts.any((s) => s.source.contains("'Gesture'")), isTrue);
    });
  });
}

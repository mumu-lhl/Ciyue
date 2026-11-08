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
      expect(script, contains("if (leftDown && !e.ctrlKey)"));
      expect(script, contains("if (e.ctrlKey) return;"));
    });

    test("falls back to contextmenu without sending the rocker twice", () {
      expect(script, contains("sendRocker();"));
      expect(script, contains("if (rockerSent) return;"));
      expect(script, contains("rockerSent = false;"));
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

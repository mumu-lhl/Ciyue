import "package:ciyue/ui/core/word_display/desktop_context_menu_script.dart";
import "package:ciyue/ui/core/word_display/webview_widgets.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("desktopContextMenuScript", () {
    final script = desktopContextMenuScript();

    test("reports the pointer and the word through the key bridge", () {
      expect(script, contains("'ciyueKey', 'DesktopContextMenu'"));
      expect(script, contains("word: wordAt(e.clientX, e.clientY)"));
      expect(script, contains("x: e.clientX"));
    });

    test("keeps an existing selection under the pointer", () {
      expect(script, contains("getClientRects()"));
      expect(script, contains("return text;"));
    });

    test("leaves rocker gestures alone", () {
      expect(script, contains("leftDown = true"));
      expect(script, contains("if (e.button !== 2 || leftDown) return;"));
    });

    test("suppresses the engine menu", () {
      expect(script, contains("document.addEventListener('contextmenu'"));
      expect(script, contains("e.preventDefault();"));
    });
  });

  group("parseDesktopContextMenu", () {
    test("decodes a position and a word", () {
      final request = parseDesktopContextMenu(
        '{"x":12.5,"y":40,"word":"  word  "}',
      );
      expect(request?.x, 12.5);
      expect(request?.y, 40);
      expect(request?.word, "word");
    });

    test("rejects malformed messages", () {
      expect(parseDesktopContextMenu("not json"), isNull);
      expect(parseDesktopContextMenu("[]"), isNull);
      expect(parseDesktopContextMenu('{"x":1,"y":2,"word":3}'), isNull);
      expect(parseDesktopContextMenu('{"x":"1","y":2}'), isNull);
    });
  });

  group("dictionaryUserScripts desktop menu", () {
    test("keeps the word script by default", () {
      final scripts = dictionaryUserScripts();
      expect(scripts, hasLength(8));
      expect(
        scripts.any((s) => s.source.contains("'DesktopContextMenu'")),
        isFalse,
      );
      expect(scripts.any((s) => s.source.contains("'ContextWord'")), isTrue);
    });

    test("swaps in the app menu script only when asked", () {
      final scripts = dictionaryUserScripts(desktopContextMenu: true);
      expect(scripts, hasLength(8));
      expect(
        scripts.any((s) => s.source.contains("'DesktopContextMenu'")),
        isTrue,
      );
      expect(scripts.any((s) => s.source.contains("'ContextWord'")), isFalse);
    });

    test("Windows/Linux keep gestures alongside their own menu", () {
      final scripts = dictionaryUserScripts(
        isDesktop: true,
        desktopContextMenu: true,
      );
      expect(scripts, hasLength(9));
      expect(scripts.any((s) => s.source.contains("'Gesture'")), isTrue);
      expect(
        scripts.any((s) => s.source.contains("'DesktopContextMenu'")),
        isTrue,
      );
    });

    test("macOS keeps the gesture and word scripts unchanged", () {
      final scripts = dictionaryUserScripts(isDesktop: true);
      expect(scripts, hasLength(9));
      expect(scripts.any((s) => s.source.contains("'Gesture'")), isTrue);
      expect(scripts.any((s) => s.source.contains("'ContextWord'")), isTrue);
      expect(
        scripts.any((s) => s.source.contains("'DesktopContextMenu'")),
        isFalse,
      );
    });
  });
}

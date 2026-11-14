import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/word_display/content_scale_script.dart";
import "package:ciyue/ui/core/word_display/key_bridge_script.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
import "package:ciyue/ui/pages/main/home/shortcuts.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("clampContentScale", () {
    test("keeps a value inside the range", () {
      expect(clampContentScale(1.0), 1.0);
      expect(clampContentScale(0.5), minContentScale);
      expect(clampContentScale(2.0), maxContentScale);
    });

    test("clamps a value outside the range", () {
      expect(clampContentScale(0.0), minContentScale);
      expect(clampContentScale(-3.0), minContentScale);
      expect(clampContentScale(5.0), maxContentScale);
    });
  });

  group("contentScaleScript", () {
    test("applies the scale to the root element", () {
      final script = contentScaleScript(1.25);
      expect(script, contains("1.250"));
      expect(script, contains("root.style.zoom = v"));
      expect(script, contains("window.ciyueSetZoom"));
    });
  });

  group("keyBridgeScript", () {
    test("forwards Alt+PageUp and Alt+PageDown", () {
      final script = keyBridgeScript();
      expect(script, contains("['PageUp', false, true, false, false]"));
      expect(script, contains("['PageDown', false, true, false, false]"));
    });

    test("takes the plain page keys over only in the e-ink mode", () {
      final script = keyBridgeScript();
      // Without the mode the WebView keeps PageUp/PageDown and scrolls
      // itself, which is what the tab layout relies on.
      expect(script, contains("plainPageKey"));
      expect(script, contains("!window.ciyuePagingEnabled"));
    });

    test("forwards Alt+Arrow for history only", () {
      final script = keyBridgeScript();
      expect(script, contains("['ArrowUp', false, true, false, false]"));
      expect(script, contains("['ArrowDown', false, true, false, false]"));
      expect(script, isNot(contains("['ArrowUp', true, false, false, false]")));
      // The meta column stays so a Cmd combination cannot be forwarded as
      // the same key without its modifier.
      expect(script, contains("s[4] === e.metaKey"));
    });
  });

  group("dictTabIndexForNumber", () {
    test("maps the AI tab", () {
      expect(
        dictTabIndexForNumber(
          number: 0,
          aiExplainWord: true,
          dictionaryCount: 3,
        ),
        0,
      );
      expect(
        dictTabIndexForNumber(
          number: 0,
          aiExplainWord: false,
          dictionaryCount: 3,
        ),
        isNull,
      );
    });

    test("maps the dictionaries", () {
      expect(
        dictTabIndexForNumber(
          number: 1,
          aiExplainWord: false,
          dictionaryCount: 3,
        ),
        0,
      );
      expect(
        dictTabIndexForNumber(
          number: 3,
          aiExplainWord: false,
          dictionaryCount: 3,
        ),
        2,
      );
      expect(
        dictTabIndexForNumber(
          number: 1,
          aiExplainWord: true,
          dictionaryCount: 3,
        ),
        1,
      );
      expect(
        dictTabIndexForNumber(
          number: 3,
          aiExplainWord: true,
          dictionaryCount: 3,
        ),
        3,
      );
    });

    test("returns null past the last dictionary", () {
      expect(
        dictTabIndexForNumber(
          number: 4,
          aiExplainWord: false,
          dictionaryCount: 3,
        ),
        isNull,
      );
      expect(
        dictTabIndexForNumber(
          number: 4,
          aiExplainWord: true,
          dictionaryCount: 3,
        ),
        isNull,
      );
    });

    test("returns null when there is no dictionary", () {
      expect(
        dictTabIndexForNumber(
          number: 1,
          aiExplainWord: false,
          dictionaryCount: 0,
        ),
        isNull,
      );
      expect(
        dictTabIndexForNumber(
          number: 1,
          aiExplainWord: true,
          dictionaryCount: 0,
        ),
        isNull,
      );
    });
  });

  group("adjacentDictTabIndex", () {
    test("steps through the tabs", () {
      expect(adjacentDictTabIndex(current: 1, length: 4, step: 1), 2);
      expect(adjacentDictTabIndex(current: 1, length: 4, step: -1), 0);
    });

    test("wraps at either end", () {
      expect(adjacentDictTabIndex(current: 3, length: 4, step: 1), 0);
      expect(adjacentDictTabIndex(current: 0, length: 4, step: -1), 3);
    });

    test("clamps an index from a tab bar that changed", () {
      expect(adjacentDictTabIndex(current: 9, length: 4, step: 1), 0);
    });

    test("returns null when there is nothing to step between", () {
      expect(adjacentDictTabIndex(current: 0, length: 0, step: 1), isNull);
      expect(adjacentDictTabIndex(current: 0, length: 1, step: 1), isNull);
    });
  });

  group("bridgeShortcutActivator", () {
    test("keeps the meta flag", () {
      final activator = bridgeShortcutActivator(
        '{"code":"ArrowUp","meta":true}',
      );
      expect(activator, isNotNull);
      expect(activator!.trigger, LogicalKeyboardKey.arrowUp);
      expect(activator.meta, isTrue);
      expect(activator.control, isFalse);
    });
  });

  group("ShortcutDispatcher", () {
    test("runs an action once when both paths see the same press", () {
      final dispatcher = ShortcutDispatcher();
      var calls = 0;
      const activator = SingleActivator(LogicalKeyboardKey.arrowUp, meta: true);
      final bindings = <SingleActivator, VoidCallback>{
        activator: () => calls++,
      };
      expect(dispatcher.dispatch(bindings, activator), isTrue);
      expect(dispatcher.dispatch(bindings, activator), isTrue);
      expect(calls, 1);
    });

    test("keeps key repeats running", () {
      final dispatcher = ShortcutDispatcher();
      var calls = 0;
      const activator = SingleActivator(
        LogicalKeyboardKey.arrowDown,
        control: true,
      );
      final bindings = <SingleActivator, VoidCallback>{
        activator: () => calls++,
      };
      expect(dispatcher.dispatch(bindings, activator), isTrue);
      expect(dispatcher.dispatch(bindings, activator, isRepeat: true), isTrue);
      expect(calls, 2);
    });

    test("leaves unbound keys alone", () {
      final dispatcher = ShortcutDispatcher();
      const activator = SingleActivator(LogicalKeyboardKey.keyQ);
      expect(
        dispatcher.dispatch(const <SingleActivator, VoidCallback>{}, activator),
        isFalse,
      );
    });
  });
}

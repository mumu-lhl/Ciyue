import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/word_display/gesture_actions.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("parseGesture", () {
    test("reads a rocker and a wheel gesture", () {
      final rocker = parseGesture('{"kind":"rocker","direction":1}');
      expect(rocker, isNotNull);
      expect(rocker!.kind, GestureKind.rocker);
      expect(rocker.direction, 1);

      final wheel = parseGesture('{"kind":"wheel","direction":-1}');
      expect(wheel, isNotNull);
      expect(wheel!.kind, GestureKind.wheel);
      expect(wheel.direction, -1);
    });

    test("rejects malformed payloads", () {
      expect(parseGesture("not json"), isNull);
      expect(parseGesture("{}"), isNull);
      expect(parseGesture('{"kind":"other","direction":1}'), isNull);
      expect(parseGesture('{"kind":"wheel","direction":0}'), isNull);
      expect(parseGesture('{"kind":"wheel","direction":2}'), isNull);
      expect(parseGesture('{"kind":"wheel","direction":"up"}'), isNull);
    });
  });

  group("resolveGestureAction", () {
    test("off stays off", () {
      expect(
        resolveGestureAction(MouseGestureAction.off, true),
        MouseGestureAction.off,
      );
      expect(
        resolveGestureAction(MouseGestureAction.off, false),
        MouseGestureAction.off,
      );
    });

    test("dictionary tabs fall back to word tabs in the expansion layout", () {
      expect(
        resolveGestureAction(MouseGestureAction.dictionaryTabs, false),
        MouseGestureAction.wordTabs,
      );
      expect(
        resolveGestureAction(MouseGestureAction.dictionaryTabs, true),
        MouseGestureAction.dictionaryTabs,
      );
    });

    test("word tabs are layout independent", () {
      expect(
        resolveGestureAction(MouseGestureAction.wordTabs, false),
        MouseGestureAction.wordTabs,
      );
      expect(
        resolveGestureAction(MouseGestureAction.wordTabs, true),
        MouseGestureAction.wordTabs,
      );
    });
  });
}

import "package:ciyue/ui/core/word_display/windows_rocker_edge.dart";
import "package:flutter/gestures.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("WindowsRockerEdgeDetector", () {
    test("fires once on a right-button edge while the left button is held", () {
      final detector = WindowsRockerEdgeDetector();
      expect(detector.update(kPrimaryMouseButton), isFalse);
      expect(
        detector.update(kPrimaryMouseButton | kSecondaryMouseButton),
        isTrue,
      );
      expect(
        detector.update(kPrimaryMouseButton | kSecondaryMouseButton),
        isFalse,
      );
    });

    test("fires again after the right button is released", () {
      final detector = WindowsRockerEdgeDetector();
      expect(
        detector.update(kPrimaryMouseButton | kSecondaryMouseButton),
        isTrue,
      );
      expect(detector.update(kPrimaryMouseButton), isFalse);
      expect(
        detector.update(kPrimaryMouseButton | kSecondaryMouseButton),
        isTrue,
      );
    });

    test("resets when all buttons are released", () {
      final detector = WindowsRockerEdgeDetector();
      detector.update(kPrimaryMouseButton | kSecondaryMouseButton);
      expect(detector.update(0), isFalse);
      expect(detector.update(kSecondaryMouseButton), isTrue);
    });

    test("reports a bare right edge; the script filters it", () {
      // A right press on its own is a real PointerDownEvent in WebView2. The
      // detector reports it anyway; the script's leftDown guard decides.
      final detector = WindowsRockerEdgeDetector();
      expect(detector.update(kSecondaryMouseButton), isTrue);
    });
  });
}

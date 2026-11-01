import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/word_display/content_scale_script.dart";
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
}

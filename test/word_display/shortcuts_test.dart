import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/word_display/content_scale_script.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
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
}

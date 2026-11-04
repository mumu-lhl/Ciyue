import "dart:convert";

import "package:ciyue/services/text_encoding.dart";
import "package:flutter_test/flutter_test.dart";

List<int> _utf16le(String value) => [
  for (final unit in value.codeUnits) ...[unit & 0xFF, unit >> 8],
];

List<int> _utf16be(String value) => [
  for (final unit in value.codeUnits) ...[unit >> 8, unit & 0xFF],
];

void main() {
  group("guessTextCharset", () {
    test("plain UTF-8", () {
      expect(guessTextCharset(utf8.encode("body { color: red; }")), "utf-8");
    });

    test("UTF-8 with a BOM", () {
      expect(
        guessTextCharset([0xEF, 0xBB, 0xBF, ...utf8.encode("body{}")]),
        "utf-8",
      );
    });

    test("UTF-16LE with a BOM", () {
      expect(guessTextCharset([0xFF, 0xFE, ..._utf16le("body{}")]), "utf-16le");
    });

    test("UTF-16BE with a BOM", () {
      expect(guessTextCharset([0xFE, 0xFF, ..._utf16be("body{}")]), "utf-16be");
    });

    test("UTF-16LE without a BOM is detected from NUL bytes", () {
      expect(guessTextCharset(_utf16le("body { color: red; }")), "utf-16le");
    });

    test("UTF-16BE without a BOM is detected from NUL bytes", () {
      expect(guessTextCharset(_utf16be("body { color: red; }")), "utf-16be");
    });

    test("bytes that are neither UTF-8 nor UTF-16 give null", () {
      // GBK for 中文: invalid UTF-8, no NUL padding.
      expect(guessTextCharset([0xD6, 0xD0, 0xCE, 0xC4]), isNull);
    });
  });

  group("resourceContentType", () {
    test("pins the detected charset for a UTF-16 stylesheet", () {
      expect(
        resourceContentType("dict.css", _utf16le("body{}")),
        "text/css; charset=utf-16le",
      );
    });

    test("pins UTF-8 when the sheet claims utf-16 but is UTF-8", () {
      expect(
        resourceContentType(
          "dict.css",
          utf8.encode('@charset "utf-16";\nbody { color: red; }'),
        ),
        "text/css; charset=utf-8",
      );
    });

    test("pins the charset for scripts", () {
      expect(
        resourceContentType("dict.js", utf8.encode("var a = 1;")),
        "application/javascript; charset=utf-8",
      );
    });

    test("leaves non-text resources untouched", () {
      expect(resourceContentType("cover.png", [1, 2, 3]), "image/png");
    });
  });
}

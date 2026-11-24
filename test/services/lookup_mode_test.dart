import "package:ciyue/services/lookup_mode.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("decideLookupMode", () {
    test("single word is a lookup", () {
      expect(decideLookupMode("hello"), LookupMode.lookup);
    });

    test("short phrase is a lookup", () {
      expect(decideLookupMode("break the ice"), LookupMode.lookup);
    });

    test("exactly five words is still a lookup", () {
      expect(decideLookupMode("the best of both worlds"), LookupMode.lookup);
    });

    test("six words is a translation", () {
      expect(
        decideLookupMode("the best of both worlds today"),
        LookupMode.translate,
      );
    });

    test("nine-word sentence is a translation", () {
      expect(
        decideLookupMode("The quick brown fox jumps over the lazy dog"),
        LookupMode.translate,
      );
    });

    test("short Chinese word is a lookup", () {
      expect(decideLookupMode("你好世界"), LookupMode.lookup);
    });

    test("an eleven-letter Latin word is still a lookup", () {
      expect(decideLookupMode("serendipity"), LookupMode.lookup);
    });

    test("exactly ten CJK runes without whitespace is still a lookup", () {
      expect(decideLookupMode("一二三四五六七八九十"), LookupMode.lookup);
    });

    test("eleven CJK runes without whitespace is a translation", () {
      expect(decideLookupMode("一二三四五六七八九十一"), LookupMode.translate);
    });

    test("twelve-character Chinese sentence is a translation", () {
      expect(decideLookupMode("今天天气很好我们去散步吧"), LookupMode.translate);
    });

    test("text containing a newline is a translation", () {
      expect(decideLookupMode("Hello.\nHow are you?"), LookupMode.translate);
    });

    test("two sentences are a translation", () {
      expect(
        decideLookupMode("Hello world. How are you?"),
        LookupMode.translate,
      );
    });

    test("two CJK sentences are a translation", () {
      expect(decideLookupMode("你好吗？我很好。"), LookupMode.translate);
    });

    test("empty text is a lookup", () {
      expect(decideLookupMode(""), LookupMode.lookup);
    });

    test("whitespace-only text is a lookup", () {
      expect(decideLookupMode("   \n\t  "), LookupMode.lookup);
    });

    test("a single trailing question mark does not make two sentences", () {
      expect(decideLookupMode("Hello world?"), LookupMode.lookup);
    });

    test("a single trailing exclamation mark does not make two sentences", () {
      expect(decideLookupMode("Hello world!"), LookupMode.lookup);
    });

    test(
      "a trailing cluster of marks is one exclamation, not two sentences",
      () {
        expect(decideLookupMode("Hello?!"), LookupMode.lookup);
      },
    );

    test("two sentences ending in a terminator are a translation", () {
      expect(decideLookupMode("Hello. World."), LookupMode.translate);
    });

    test("one mid-sentence exclamation mark is a translation", () {
      expect(decideLookupMode("Hello! How are you"), LookupMode.translate);
    });

    test("one mid-sentence CJK terminator is a translation", () {
      expect(decideLookupMode("今天天气很好。明天会下雨"), LookupMode.translate);
    });

    test("a single mid-sentence period is a translation", () {
      expect(decideLookupMode("Hello. World"), LookupMode.translate);
    });

    test("\"e.g.\" is an abbreviation, not a sentence boundary", () {
      expect(decideLookupMode("e.g."), LookupMode.lookup);
    });

    test("\"U.S.A.\" is an abbreviation, not sentences", () {
      expect(decideLookupMode("U.S.A."), LookupMode.lookup);
    });

    test("\"Ph.D.\" is an abbreviation, not sentences", () {
      expect(decideLookupMode("Ph.D."), LookupMode.lookup);
    });

    test("a version number is a lookup, not sentences", () {
      expect(decideLookupMode("Version 1.2.3"), LookupMode.lookup);
    });

    test("a dotted decimal is a lookup", () {
      expect(decideLookupMode("3.14"), LookupMode.lookup);
    });

    test("a bare version number is a lookup", () {
      expect(decideLookupMode("1.2.3"), LookupMode.lookup);
    });

    test("a digit string just over ten runes has no headword", () {
      expect(decideLookupMode("12345678901"), LookupMode.translate);
    });

    test("pure punctuation has no headword to look up", () {
      expect(decideLookupMode("!!!"), LookupMode.translate);
    });

    test("a long digit string has no headword to look up", () {
      expect(decideLookupMode("123456789012345"), LookupMode.translate);
    });

    test("a URL has no headword to look up", () {
      expect(
        decideLookupMode("https://example.com/a/very/long/path"),
        LookupMode.translate,
      );
    });

    test("a schemeless URL has no headword to look up", () {
      expect(
        decideLookupMode("example.com/a/very/long/path"),
        LookupMode.translate,
      );
    });
  });
}

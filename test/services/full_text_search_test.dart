import "package:ciyue/services/full_text_search.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("stripHtmlToText", () {
    test("drops tags and decodes entities", () {
      expect(
        stripHtmlToText("<p>Hello &amp; <b>world</b></p>"),
        "Hello & world",
      );
    });

    test("drops script and style blocks entirely", () {
      expect(
        stripHtmlToText(
          "<style>.x{color:red}</style><p>keep</p>"
          "<script>var x = 1;</script>",
        ),
        "keep",
      );
    });

    test("collapses whitespace and breaks", () {
      expect(stripHtmlToText("<p>one</p><p>two</p><br>three"), "one two three");
    });

    test("leaves plain text alone", () {
      expect(stripHtmlToText("plain definition"), "plain definition");
    });
  });

  group("tokenizeForIndex", () {
    test("splits CJK characters apart, keeps Latin words whole", () {
      expect(tokenizeForIndex("苹果是一种水果"), "苹 果 是 一 种 水 果");
      expect(tokenizeForIndex("apple pie 苹果派"), "apple pie 苹 果 派");
    });

    test("does not add leading or trailing spaces", () {
      expect(tokenizeForIndex(" 苹果 "), "苹 果");
    });
  });

  group("buildFtsMatchExpression", () {
    test("single Latin word becomes a phrase", () {
      expect(buildFtsMatchExpression("apple"), '"apple"');
    });

    test("CJK run becomes a character phrase", () {
      expect(buildFtsMatchExpression("苹果"), '"苹 果"');
    });

    test("mixed query ANDs its terms", () {
      expect(buildFtsMatchExpression("苹果 pie"), '"苹 果" AND "pie"');
      expect(buildFtsMatchExpression("苹果apple"), '"苹 果" AND "apple"');
    });

    test("quotes inside a term are doubled, not syntax", () {
      expect(buildFtsMatchExpression('say "hi"'), '"say" AND """hi"""');
    });

    test("punctuation-only and empty queries have no expression", () {
      expect(buildFtsMatchExpression("..."), "");
      expect(buildFtsMatchExpression("   "), "");
    });
  });

  group("parseSnippet", () {
    test("splits markers into plain and match segments", () {
      final segments = parseSnippet(
        "a $snippetMatchStart"
        "match$snippetMatchEnd b",
      );
      expect(segments.map((s) => (s.text, s.isMatch)).toList(), [
        ("a ", false),
        ("match", true),
        (" b", false),
      ]);
    });

    test("unmatched markers degrade to plain text", () {
      final segments = parseSnippet("no markers here");
      expect(segments, hasLength(1));
      expect(segments.single.isMatch, isFalse);
    });
  });
}

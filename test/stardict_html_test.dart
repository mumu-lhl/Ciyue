import "dart:typed_data";

import "package:ciyue/services/stardict_html.dart";
import "package:dict_reader/dict_reader.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("stardictEntryToHtml", () {
    test("escapes plain text and converts line breaks", () {
      final html = stardictEntryToHtml([
        const StarDictField("m", text: "a <fruit>\nsecond line"),
      ]);
      expect(html, contains("a &lt;fruit&gt;<br>second line"));
    });

    test("passes HTML fields through unchanged", () {
      final html = stardictEntryToHtml([
        const StarDictField("h", text: "<b>bold</b>"),
      ]);
      expect(html, "<b>bold</b>");
    });

    test("wraps phonetics in brackets", () {
      final html = stardictEntryToHtml([
        const StarDictField("t", text: "'æpl"),
      ]);
      expect(html, contains("[&#39;æpl]"));
    });

    test("skips binary fields", () {
      final html = stardictEntryToHtml([
        const StarDictField("m", text: "text"),
        StarDictField("W", data: Uint8List.fromList([1, 2, 3])),
      ]);
      expect(html, contains("text"));
      expect(html.length, lessThan(60));
    });
  });

  group("pangoToHtml", () {
    test("keeps inline tags and maps span colors", () {
      final html = pangoToHtml('<b>bold</b> <span foreground="red">red</span>');
      expect(html, contains("<b>bold</b>"));
      expect(html, contains('<span style="color:red">red</span>'));
    });

    test("escapes text nodes", () {
      expect(pangoToHtml("a & b"), contains("a &amp; b"));
    });
  });

  group("xdxfToHtml", () {
    const xdxf =
        "<xdxf lang_from=\"ENG\" lang_to=\"ZHO\">"
        "<k>apple</k>"
        "<def><gr>noun</gr> <tr>'æpl</tr> "
        "<dtrn>苹果</dtrn>"
        "<ex><exorig>I eat an apple.</exorig><extr>我吃一个苹果。</extr></ex>"
        "<co>see also <kref>fruit</kref></co>"
        "</def></xdxf>";

    test("converts the article structure", () {
      final html = xdxfToHtml(xdxf);
      expect(html, contains('<div class="sd-k"><b>apple</b></div>'));
      expect(html, contains('<span class="sd-gr"><i>noun</i></span>'));
      expect(html, contains("<span class=\"sd-tr\">[&#39;æpl]</span>"));
      expect(html, contains("苹果"));
      expect(html, contains('<span class="sd-exorig">I eat an apple.</span>'));
      expect(html, contains('<span class="sd-extr">我吃一个苹果。</span>'));
    });

    test("turns kref into an entry:// link", () {
      final html = xdxfToHtml(xdxf);
      expect(html, contains('<a href="entry://fruit">fruit</a>'));
    });

    test("renders rref images from the res folder", () {
      final html = xdxfToHtml(
        "<xdxf><k>x</k><def><rref>pic.png</rref></def></xdxf>",
      );
      expect(html, contains('<img src="res/pic.png"'));
    });

    test("falls back to plain text for malformed XML", () {
      final html = xdxfToHtml("<xdxf><k>unclosed");
      expect(html, contains("unclosed"));
      expect(html, contains('class="sd-text"'));
    });
  });
}

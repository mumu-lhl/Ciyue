import "package:ciyue/services/lookup_keys.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("widthVariants", () {
    test("ASCII full-width <-> half-width, both directions", () {
      expect(widthVariants("NHK"), containsAll(["NHK", "ＮＨＫ"]));
      expect(widthVariants("ＮＨＫ"), containsAll(["ＮＨＫ", "NHK"]));
      expect(widthVariants("RPG"), containsAll(["RPG", "ＲＰＧ"]));
    });

    test("digits fold both ways", () {
      expect(widthVariants("007"), containsAll(["007", "００７"]));
    });

    test("corner brackets ｢｣ <-> 「」", () {
      expect(widthVariants("｢名前｣"), containsAll(["｢名前｣", "「名前」"]));
      expect(widthVariants("「名前」"), containsAll(["「名前」", "｢名前｣"]));
    });

    test("CJK marks ｡､･ <-> 。、・", () {
      expect(widthVariants("｡"), containsAll(["｡", "。"]));
      expect(widthVariants("､"), containsAll(["､", "、"]));
      expect(widthVariants("･"), containsAll(["･", "・"]));
    });

    test("half-width/ideographic space  \u0020 <-> \u3000", () {
      // Each rune maps independently, so the letters go full-width too.
      expect(widthVariants("a b"), containsAll(["a b", "ａ\u3000ｂ"]));
      expect(widthVariants("ａ\u3000ｂ"), containsAll(["ａ\u3000ｂ", "a b"]));
    });

    test("leaves half-width katakana (non-bijection) alone", () {
      // ﾊﾞ must not collapse to a single full-width codepoint here.
      expect(widthVariants("ﾊﾞ"), ["ﾊﾞ"]);
    });

    test("ordinary full-width kana is unchanged", () {
      expect(widthVariants("カタカナ"), ["カタカナ"]);
    });
  });

  group("normalizePersonalHeadword folds full-width spellings", () {
    test("full-width ASCII folds to half-width", () {
      expect(normalizePersonalHeadword("Ａpple"), "apple");
      expect(normalizePersonalHeadword("ＮＨＫ"), "nhk");
      expect(normalizePersonalHeadword("００７"), "007");
    });

    test("ideographic space folds to a space", () {
      expect(normalizePersonalHeadword("ａ　ｂ"), "a b");
    });

    test("half-width CJK marks fold to their full-width forms", () {
      expect(normalizePersonalHeadword("｢名前｣"), "「名前」");
      expect(normalizePersonalHeadword("｡"), "。");
      expect(normalizePersonalHeadword("､"), "、");
      expect(normalizePersonalHeadword("･"), "・");
    });

    test("half-width ASCII and kana are unchanged", () {
      expect(normalizePersonalHeadword("Apple"), "apple");
      expect(normalizePersonalHeadword("パソコン"), "パソコン");
    });
  });

  group("lookupVariants crosses case with width", () {
    test("typed full-width lowercase reaches half-width upper", () {
      final variants = lookupVariants("ｎｈｋ");
      expect(variants, containsAll(["ｎｈｋ", "ＮＨＫ", "nhk", "NHK", "Nhk"]));
      expect(variants.first, "ｎｈｋ");
    });

    test("typed half-width upper reaches full-width lower", () {
      final variants = lookupVariants("NHK");
      expect(variants, containsAll(["NHK", "nhk", "Nhk", "ＮＨＫ", "ｎｈｋ"]));
      expect(variants.first, "NHK");
    });

    test("no width change keeps the plain case variants", () {
      expect(
        lookupVariants("Nahida"),
        containsAll(["Nahida", "nahida", "NAHIDA"]),
      );
    });
  });

  group("lookupVariants cache (P0-4)", () {
    test("returns the same list for the same word", () {
      // The cache hands back the built list itself, so a repeat call does
      // no regex title-casing at all.
      final first = lookupVariants("Nahida");
      final second = lookupVariants("Nahida");
      expect(identical(first, second), isTrue);
      expect(first, containsAll(["Nahida", "nahida", "NAHIDA"]));
    });

    test("the cache is bounded and evicts the oldest entry", () {
      const probe = "evictProbeWord";
      final first = lookupVariants(probe);
      for (var i = 0; i < 512; i++) {
        lookupVariants("$probe-$i");
      }
      final second = lookupVariants(probe);
      expect(identical(first, second), isFalse);
      expect(second, first);
    });
  });
}

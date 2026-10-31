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

  group("lookupVariants crosses case with width", () {
    test("typed full-width lowercase reaches half-width upper", () {
      // ｎｈｋ -> {ｎｈｋ, ＮＨＫ, nhk, NHK, Nhk}.
      final variants = lookupVariants("ｎｈｋ");
      expect(variants, containsAll(["ｎｈｋ", "ＮＨＫ", "nhk", "NHK", "Nhk"]));
      // Original as typed stays first.
      expect(variants.first, "ｎｈｋ");
    });

    test("typed half-width upper reaches full-width lower", () {
      // NHK -> {NHK, nhk, Nhk, ＮＨＫ, ｎｈｋ}.
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
}

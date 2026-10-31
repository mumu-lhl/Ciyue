/// Spellings worth trying when the exact one resolves to nothing.
///
/// Dictionaries keep words the way their author wrote them, so the same word
/// can arrive with different capitalisation (`Nahida` typed as `nahida`) or in
/// a different kana script (`パソコン` typed as `ぱそこん`). Normalising the
/// index would need a new `.cidx` format, so the lookup enumerates the few
/// spellings a dictionary might actually use and reads whichever of them
/// exists — the exact spelling first, so the closest match is also the first
/// one shown.
///
/// Deliberately **not** handled here:
///
/// - **Width folding (the 1:1 subset)**: full-width ASCII (`ＮＨＫ`), the
///   full-width/ideographic space (`　` <-> ` `), corner brackets (`｢｣` <->
///   `「」`) and the half-width CJK marks (`｡､･` <-> `。、・`) are now
///   enumerated in [widthVariants] — each is a bijection, so
///   safe to list like the kana swap. Half-width katakana *proper* (`ﾊﾟｿｺﾝ`) is
///   not a clean 1:1 (a voiced mark is a second codepoint: `ﾊﾞ` is two chars),
///   so it still belongs in a query-time normalisation step (see the `ICONV`
///   table of `hunspell_ja_JP`), not here.
/// - **Long vowel expansion** (`ふーぞく` -> `ふうぞく`): not a bijection, the
///   vowel depends on the preceding kana and both `こう`/こお exist. It lives in
///   `long_vowel_lookup.dart` instead, among the "not found" suggestions, where
///   the user picks a reading rather than the lookup reading one for them.
/// - **`ß` -> `ss`, Greek final sigma, diacritics**: those are one-to-many
///   folds (Unicode full case folding), and enumerate badly — a query-side
///   fold would have to guess where in the word the fold happened. They belong
///   to the index side, next to the existing NFC lookup key.
library;

/// Case spellings of [word], most faithful first: as typed, lower case,
/// title case (word by word) and upper case.
///
/// Title casing splits on whitespace and `-`, so `der große bär` also yields
/// `Der Große Bär` and `four-wheel drive` yields `Four-Wheel Drive`.
List<String> caseVariants(String word) {
  final variants = <String>[];
  void add(String value) {
    if (value.isNotEmpty && !variants.contains(value)) {
      variants.add(value);
    }
  }

  add(word);
  final lower = word.toLowerCase();
  add(lower);
  add(_capitaliseWords(lower));
  add(word.toUpperCase());
  return variants;
}

/// [word] written in the other kana script, on top of the word as typed.
///
/// Hiragana and katakana are the same characters in two scripts, so this is a
/// bijection: `ぱそこん` gives `パソコン` and back. `ー`, `・` and the katakana
/// letters that have no hiragana counterpart (`ヷヸヹヺ`) are left alone, which
/// is why `フーゾク` becomes `ふーぞく` and not `ふうぞく`.
List<String> kanaVariants(String word) {
  final variants = <String>[];
  void add(String value) {
    if (value.isNotEmpty && !variants.contains(value)) {
      variants.add(value);
    }
  }

  add(word);
  add(_convertKana(word, toKatakana: true));
  add(_convertKana(word, toKatakana: false));
  return variants;
}

/// [word] with its full-width and half-width spellings swapped, on top of the
/// word as typed.
///
/// Only the **1:1** width pairs are enumerated here — a bijection, like the
/// kana script swap above, so it is safe to list every spelling:
///
/// - ASCII full-width `FF01..FF5E` <-> ASCII `0021..007E` (letters, digits,
///   punctuation);
/// - the half-width/ideographic space `0020` <-> `3000`;
/// - half-width corner brackets `｢｣` (`FF62/FF63`) <-> `「」` (`300C/300D`);
/// - half-width CJK marks `｡､･` (`FF61/FF64/FF65`) <-> `。、・`
///   (`3002/3001/30FB`).
///
/// Half-width katakana with a voiced/semi-voiced mark (`ﾊﾞ`) is a *2-codepoint
/// to 1-codepoint* fold — not a bijection — so it stays out of this list and is
/// left to the `ICONV` table of `hunspell_ja_JP` instead.
List<String> widthVariants(String word) {
  final mapped = _mapWidth(word);
  if (mapped == word) return [word];
  return [word, mapped];
}

/// Swaps each rune of [value] between its full-width and half-width form for
/// the 1:1 ranges handled by [widthVariants], leaving everything else
/// untouched.
String _mapWidth(String value) {
  return String.fromCharCodes(
    value.runes.map((rune) {
      // ASCII full-width -> ASCII, and ASCII -> ASCII full-width.
      if (rune >= 0xFF01 && rune <= 0xFF5E) return rune - 0xFEE0;
      if (rune >= 0x21 && rune <= 0x7E) return rune + 0xFEE0;
      // Space and half-width CJK marks / corner brackets <-> their
      // full-width forms. The space (U+0020 <-> U+3000) is a 1:1 fold too,
      // but it sits outside the ASCII range and must not take the `+0xFEE0`
      // offset (that would land on the non-character U+FF00).
      switch (rune) {
        case 0x20:
          return 0x3000; // ' ' -> '　'
        case 0x3000:
          return 0x20; // '　' -> ' '
        case 0xFF61:
          return 0x3002; // ｡ -> 。
        case 0xFF62:
          return 0x300C; // ｢ -> 「
        case 0xFF63:
          return 0x300D; // ｣ -> 」
        case 0xFF64:
          return 0x3001; // ､ -> 、
        case 0xFF65:
          return 0x30FB; // ･ -> ・
        case 0x3002:
          return 0xFF61; // 。 -> ｡
        case 0x300C:
          return 0xFF62; // 「 -> ｢
        case 0x300D:
          return 0xFF63; // 」 -> ｣
        case 0x3001:
          return 0xFF64; // 、 -> ､
        case 0x30FB:
          return 0xFF65; // ・ -> ･
      }
      return rune;
    }),
  );
}

/// Every spelling worth reading for [word]: the case and full/half-width
/// spellings are crossed (every case of every width), then the kana script
/// spellings are added on top.
///
/// Crossing the two keeps the original as typed first — [widthVariants] always
/// leads with [word], and [caseVariants] re-adds it unchanged — while still
/// reaching the cross cells (e.g. typed `ｎｈｋ` also tries `NHK`, typed `NHK`
/// also tries `ｎｈｋ`).
List<String> lookupVariants(String word) {
  final variants = <String>[];
  void add(String value) {
    if (value.isNotEmpty && !variants.contains(value)) {
      variants.add(value);
    }
  }

  for (final width in widthVariants(word)) {
    for (final cased in caseVariants(width)) {
      add(cased);
    }
  }
  for (final variant in kanaVariants(word)) {
    add(variant);
  }
  return variants;
}

/// [word] written in hiragana, leaving everything that is not katakana alone.
///
/// `フーゾク` gives `ふーぞく`; the long vowel mark is shared between the two
/// scripts and stays, because writing it out is a choice the suggestions offer
/// (see `long_vowel_lookup.dart`) rather than a script conversion.
String toHiragana(String word) => _convertKana(word, toKatakana: false);

/// Capitals after whitespace or `-`, leaving everything else untouched.
String _capitaliseWords(String value) {
  return value.replaceAllMapped(RegExp(r"[^\s\-]+"), (match) {
    final word = match[0]!;
    final first = String.fromCharCode(word.runes.first);
    return first.toUpperCase() + word.substring(first.length);
  });
}

/// Hiragana and katakana occupy parallel blocks, `U+3041..U+3096` and
/// `U+30A1..U+30F6`, so the conversion is a constant offset. The iteration
/// marks `ゝゞ`/`ヽヾ` sit outside those blocks but follow the same offset.
String _convertKana(String value, {required bool toKatakana}) {
  const offset = 0x60;
  return String.fromCharCodes(
    value.runes.map((rune) {
      if (toKatakana) {
        if (rune >= 0x3041 && rune <= 0x3096) return rune + offset;
        if (rune == 0x309D || rune == 0x309E) return rune + offset;
      } else {
        if (rune >= 0x30A1 && rune <= 0x30F6) return rune - offset;
        if (rune == 0x30FD || rune == 0x30FE) return rune - offset;
      }
      // `ヷヸヹヺ` (U+30F7..U+30FA) have no hiragana form, and `ー`/`・` are
      // shared between the two scripts.
      return rune;
    }),
  );
}

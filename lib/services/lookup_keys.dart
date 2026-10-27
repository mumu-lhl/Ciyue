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
/// - **Half-width katakana** (`ﾊﾟｿｺﾝ`): an encoding of the same text rather than
///   another spelling of a word, and Japanese dictionaries almost never use it
///   as a headword. If it is ever needed, it belongs in a query-time
///   normalisation step (see the `ICONV` table of `hunspell_ja_JP`), not in
///   this list.
/// - **Long vowel expansion** (`ふーぞく` -> `ふうぞく`): not a bijection, the
///   vowel depends on the preceding kana and both `こう`/こお exist. It belongs
///   in the "not found" suggestions, where the user picks, rather than in the
///   candidates that are read directly.
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

/// Every spelling worth reading for [word]: case variants first, then kana.
List<String> lookupVariants(String word) {
  final variants = <String>[];
  void add(String value) {
    if (value.isNotEmpty && !variants.contains(value)) {
      variants.add(value);
    }
  }

  for (final variant in caseVariants(word)) {
    add(variant);
  }
  for (final variant in kanaVariants(word)) {
    add(variant);
  }
  return variants;
}

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

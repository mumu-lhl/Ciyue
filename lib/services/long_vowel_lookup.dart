/// Reads a kana word whose long vowels are marked with `ー` as the hiragana
/// spelling that writes those vowels out.
///
/// A loanword is written in katakana with `ー` standing for a long vowel —
/// `フーゾク` for ふうぞく, `トーキョー` for とうきょう — while dictionaries,
/// and the prose quoting them, often use hiragana with the vowel spelled out.
/// The two strings are the same word, and neither is reachable from the other
/// by script conversion: `ー` says how long the vowel is, not which vowel, and
/// that has to be read off the kana before it.
///
/// The mark is ambiguous where a long vowel has two common spellings — a long
/// `e` is えい or ええ, a long `o` is おう or おお — so every reading is
/// generated and the dictionaries decide which of them exists. That is also why
/// this is a separate pass rather than part of `lookupVariants`, which is a
/// bijection and cannot branch.
library;

import "package:ciyue/services/lookup_keys.dart";

const _mark = "ー";

/// Hiragana that can stand before `ー`, grouped by the vowel the mark carries.
///
/// Small kana are here because a long vowel may follow a digraph: `きょー` is
/// きょう, and it is the `ょ` that decides the vowel. Kana without a vowel —
/// `ん`, `っ` — are absent on purpose: no long vowel follows them, so there is
/// nothing to read.
const _kanaByVowel = <String, String>{
  "a": "あぁかゕさただなはばぱまゃやらゎわがざ",
  "i": "いぃきしちにひびぴみりゐぎじぢ",
  "u": "うぅくぐすずつづぬふぶぷむゆゅるゔ",
  "e": "えぇけげせぜてでねへべぺめれゑ",
  "o": "おぉこごそぞとどのほぼぽもょよろを",
};

/// What the mark is written as, given the vowel it repeats.
///
/// A long vowel is spelled as a second vowel kana, not as a copy of the one
/// before it: と + う for the とー of トーキョー, め + い for the めー of
/// メール. Two vowels have two spellings each — a long `o` is う or お, a long
/// `e` is い or え — and the commoner one comes first so that a reading which
/// is both generated and present in a dictionary is also shown first:
/// `トーキョー` gives とうきょう before とおきょう.
const _writtenOut = <String, List<String>>{
  "a": ["あ"],
  "i": ["い"],
  "u": ["う"],
  "e": ["い", "え"],
  "o": ["う", "お"],
};

/// Most readings one word may generate.
///
/// Each ambiguous mark doubles the count, and a word with four of them would
/// already offer sixteen. Real loanwords stop well short; this only keeps a
/// pasted run of marks from turning into a combinatorial explosion.
const maxLongVowelReadings = 16;

/// Hiragana readings of [word] with every `ー` written out, most plausible
/// first.
///
/// Empty when [word] has no `ー`, and empty when one of them does not follow a
/// kana (`ンー`, `オーー`, `ーア`): the vowel would have to be invented, and a
/// made-up word is exactly what the "not found" page must not offer.
List<String> longVowelReadings(String word) {
  if (!word.contains(_mark)) return const [];

  final hiragana = toHiragana(word);
  var readings = <String>[""];

  for (var i = 0; i < hiragana.length; i++) {
    final char = hiragana[i];
    if (char != _mark) {
      readings = [for (final reading in readings) "$reading$char"];
      continue;
    }

    final vowel = i == 0 ? null : _vowelOf(hiragana[i - 1]);
    if (vowel == null) return const [];

    final expansions = _writtenOut[vowel]!;
    readings = _expand(readings, expansions);
  }
  return readings;
}

/// [readings] with one more character appended from [expansions].
///
/// The cap is applied here rather than at the end so that the readings kept are
/// the ones built from the most plausible spellings, not an arbitrary slice of
/// the full set.
List<String> _expand(List<String> readings, List<String> expansions) {
  final expanded = <String>[];
  for (final reading in readings) {
    for (final expansion in expansions) {
      expanded.add("$reading$expansion");
      if (expanded.length >= maxLongVowelReadings) return expanded;
    }
  }
  return expanded;
}

String? _vowelOf(String kana) {
  for (final entry in _kanaByVowel.entries) {
    if (entry.value.contains(kana)) return entry.key;
  }
  return null;
}

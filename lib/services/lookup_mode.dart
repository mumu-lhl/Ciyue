/// Whether a piece of selected text is a word to look up or a phrase to
/// translate.
///
/// The popup service asks [decideLookupMode] for every acquired selection:
/// a short headword goes to the dictionary, anything longer goes to the
/// translator.
enum LookupMode { lookup, translate }

const _sentenceTerminators = {".", "!", "?", "。", "！", "？"};

/// Decides how a piece of selected text should be handled.
///
/// Translates when any of these hold, otherwise looks the text up:
/// (a) more than five whitespace-separated words; (b) no whitespace at all,
/// more than ten runes, and containing a CJK character — a sentence in a
/// script without word spaces rather than a single word (a long Latin word
/// such as "serendipity" is still just a word); (c) contains a newline;
/// (d) contains a sentence boundary: an ASCII terminator followed by
/// whitespace and more text, or a CJK terminator followed by more text
/// (CJK takes no spaces). A terminator glued to the next word is an
/// abbreviation or a version number ("e.g.", "U.S.A.", "1.2.3"), not a
/// boundary, and a trailing cluster like "?!" is one exclamation rather
/// than a boundary; (e) has no headword in it at all, or looks like a URL —
/// no dictionary can answer pure punctuation, a long digit string, or a
/// link, so translating degrades more gracefully than a no-result page.
/// A schemeless address ("example.com/a/b") counts as a URL too. A short
/// digit string stays a lookup: "3.14" and "1.2.3" read as a decimal or a
/// version, not as a sentence, and only a digit run longer than ten runes
/// is treated as having no headword.
LookupMode decideLookupMode(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return LookupMode.lookup;

  if (trimmed.contains("\n") || trimmed.contains("\r")) {
    return LookupMode.translate;
  }

  if (trimmed.split(RegExp(r"\s+")).length > 5) return LookupMode.translate;

  if (!trimmed.contains(RegExp(r"\s")) &&
      trimmed.runes.length > 10 &&
      _containsCjk(trimmed)) {
    return LookupMode.translate;
  }

  if (_hasNoHeadword(trimmed) ||
      trimmed.contains("://") ||
      trimmed.startsWith("www.") ||
      (!trimmed.contains(RegExp(r"\s")) &&
          trimmed.contains("/") &&
          trimmed.contains("."))) {
    return LookupMode.translate;
  }

  for (var i = 0; i < trimmed.length; i++) {
    if (!_sentenceTerminators.contains(trimmed[i])) continue;
    if (_isSentenceBoundary(trimmed, i)) return LookupMode.translate;
  }

  return LookupMode.lookup;
}

/// Whether [text] holds a letter in any script: a headword needs one.
bool _containsLetter(String text) {
  return RegExp(r"\p{L}", unicode: true).hasMatch(text);
}

/// Whether [text] has no plausible headword: no letter at all, and either
/// no digit either (pure punctuation) or a digit run too long to be a
/// decimal or a version number.
bool _hasNoHeadword(String text) {
  if (_containsLetter(text)) return false;
  if (!RegExp(r"[0-9]").hasMatch(text)) return true;
  return text.runes.length > 10;
}

/// Whether [text] contains a character from a script without word spaces
/// (CJK Unified Ideographs and Extension A, Hiragana/Katakana, Hangul):
/// only there does a long unbroken run read as a sentence rather than one
/// long word.
bool _containsCjk(String text) {
  return text.runes.any(_isCjkRune);
}

/// Whether the terminator at [index] ends a sentence: the mark (or a
/// trailing cluster of marks) is followed by real text, with whitespace in
/// between for an ASCII terminator — CJK text after a CJK terminator needs
/// no space, and neither does CJK text after an ASCII one.
bool _isSentenceBoundary(String text, int index) {
  var j = index + 1;
  while (j < text.length && _sentenceTerminators.contains(text[j])) {
    j++;
  }
  if (j >= text.length) return false;
  var k = j;
  while (k < text.length && text[k].trim().isEmpty) {
    k++;
  }
  if (k >= text.length) return false;
  if (_isCjkTerminator(text[index])) return true;
  if (k > j) return true;
  return _isCjkRune(text.codeUnitAt(k));
}

bool _isCjkTerminator(String c) => c == "。" || c == "！" || c == "？";

bool _isCjkRune(int rune) {
  return (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0x3040 && rune <= 0x30FF) ||
      (rune >= 0xAC00 && rune <= 0xD7AF);
}

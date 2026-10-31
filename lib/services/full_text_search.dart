import "package:html_unescape/html_unescape.dart";

/// Pure helpers for full-text search: HTML stripping, CJK-aware tokenization
/// for SQLite FTS5, and FTS5 `MATCH` expression building.
///
/// This file must stay free of Flutter and app-singleton imports: the index
/// builder runs in a background isolate and imports it directly.

/// Markers wrapping a match inside an FTS5 `snippet()` result. Private-use
/// characters, so they never collide with dictionary text.
const String snippetMatchStart = "\uE000";
const String snippetMatchEnd = "\uE001";

/// One piece of a snippet: plain text, or text that matched the query.
class SnippetSegment {
  final String text;
  final bool isMatch;

  const SnippetSegment(this.text, this.isMatch);
}

/// Splits a `snippet()` result on the match markers into plain/match pieces.
/// Unmatched markers are treated as plain text.
List<SnippetSegment> parseSnippet(String marked) {
  final segments = <SnippetSegment>[];
  var rest = marked;
  while (rest.isNotEmpty) {
    final start = rest.indexOf(snippetMatchStart);
    if (start < 0) {
      segments.add(SnippetSegment(rest, false));
      break;
    }
    if (start > 0) {
      segments.add(SnippetSegment(rest.substring(0, start), false));
    }
    rest = rest.substring(start + snippetMatchStart.length);
    final end = rest.indexOf(snippetMatchEnd);
    if (end < 0) {
      segments.add(SnippetSegment(rest, true));
      break;
    }
    segments.add(SnippetSegment(rest.substring(0, end), true));
    rest = rest.substring(end + snippetMatchEnd.length);
  }
  return segments;
}

final _scriptOrStyle = RegExp(
  r"<(script|style)[^>]*>.*?</\1>",
  caseSensitive: false,
  dotAll: true,
);
final _tag = RegExp(r"<[^>]*>");
final _whitespace = RegExp(r"\s+");
final _htmlUnescape = HtmlUnescape();

/// Turns entry HTML into searchable plain text: script/style blocks and tags
/// are dropped, entities are decoded, and whitespace is collapsed.
String stripHtmlToText(String html) {
  var text = html.replaceAll(_scriptOrStyle, " ");
  text = text.replaceAll(_tag, " ");
  text = _htmlUnescape.convert(text);
  return text.replaceAll(_whitespace, " ").trim();
}

bool _isCjkRune(int rune) {
  return (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0x3041 && rune <= 0x30FF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0xAC00 && rune <= 0xD7A3) ||
      (rune >= 0x20000 && rune <= 0x2A6DF);
}

bool _isWordRune(int rune) {
  if (_isCjkRune(rune)) return true;
  final char = String.fromCharCode(rune);
  return RegExp(r"[\p{L}\p{N}]", unicode: true).hasMatch(char);
}

/// Preprocesses text for FTS5 indexing with the `unicode61` tokenizer.
///
/// `unicode61` keeps a run of CJK characters as one token, so an unsegmented
/// Chinese sentence is unsearchable word-by-word. Splitting every CJK
/// character apart makes each character its own token; Latin words are left
/// untouched. Queries go through the same splitting in
/// [buildFtsMatchExpression], so index and query agree.
String tokenizeForIndex(String text) {
  final out = StringBuffer();
  var lastWasSpace = true;
  for (final rune in text.runes) {
    if (_isCjkRune(rune)) {
      if (!lastWasSpace) out.write(" ");
      out.writeCharCode(rune);
      out.write(" ");
      lastWasSpace = true;
    } else {
      final char = String.fromCharCode(rune);
      if (char.trim().isEmpty) {
        if (!lastWasSpace) out.write(" ");
        lastWasSpace = true;
      } else {
        out.write(char);
        lastWasSpace = false;
      }
    }
  }
  return out.toString().trim();
}

/// Builds an FTS5 `MATCH` expression from a user query.
///
/// Terms are AND-ed: every whitespace-separated token must match. A CJK run
/// becomes a phrase of single-character tokens (`"苹 果"`), a Latin run
/// becomes a single-token phrase, and runs without any word character
/// (pure punctuation) are dropped. Returns "" when the query has no usable
/// term, which the caller treats as "no search".
String buildFtsMatchExpression(String query) {
  final terms = <String>[];
  for (final token in query.split(_whitespace)) {
    if (token.isEmpty) continue;
    final runes = token.runes.toList();
    var i = 0;
    while (i < runes.length) {
      final cjk = _isCjkRune(runes[i]);
      var j = i + 1;
      while (j < runes.length && _isCjkRune(runes[j]) == cjk) {
        j++;
      }
      final run = String.fromCharCodes(runes.sublist(i, j));
      if (run.runes.any(_isWordRune)) {
        if (cjk) {
          terms.add('"${run.runes.map(String.fromCharCode).join(" ")}"');
        } else {
          terms.add('"${run.replaceAll('"', '""')}"');
        }
      }
      i = j;
    }
  }
  return terms.join(" AND ");
}

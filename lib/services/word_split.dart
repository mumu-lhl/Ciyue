/// Splits a long word into headwords the loaded dictionaries already contain.
///
/// German builds compounds by concatenation (`Wohnzimmer` + `Schrank`) and
/// Chinese/Japanese is written without spaces, so a string the user copied can
/// be a run of two or three dictionary words. Neither case needs a tokeniser or
/// a language model: the dictionaries themselves are the vocabulary, and
/// asking "is this a word?" is a binary search in an index that is already in
/// memory.
///
/// The algorithm is a shortest-path DP over the positions of the word: the best
/// segmentation of the first `i` characters is extended by one headword at a
/// time. "Best" means the fewest parts, then the longest leading part — that
/// keeps `Anime + Cover` ahead of a split whose first part is a stub.
///
/// Deliberately **not** handled here:
///
/// - **Vowel changes inside a part** (`Abfälle` -> `Abfall`). That needs
///   morphology, which is a separate switch, and would double the probes.
/// - **Rare linking morphemes** (`Programm|m`-like). [_linkers] is a whitelist;
///   missing an obscure one only means a missed suggestion, never a wrong one.
/// - **Languages with other linking rules.** They would need their own table
///   behind a setting; there is no such language among the supported ones yet.
library;

import "package:ciyue/models/dictionary_lookup.dart";

/// Linking morphemes German inserts between the parts of a compound.
///
/// `Wohnzimmer|s|schrank` contains an `s` that belongs to neither part, so a
/// split that only looks for headwords cannot find it. These are hard-coded
/// rather than configurable: a language with different linking rules would need
/// its own table and a setting, and none of the supported languages has one.
/// Longest first, so `en` is tried before `e`.
const _linkers = ["en", "er", "es", "e", "n", "s"];

/// Longest input worth splitting.
///
/// Real compounds stay well under this (`Rindfleischetikettierungsüberwachungs-
/// aufgabenübertragungsgesetz` is 63 characters and nobody looks it up), and
/// the candidate set grows with the square of the length.
const maxSplitLength = 32;

/// Shortest input worth splitting: two parts need at least two characters.
const _minWordLength = 3;

/// Most parts a split may have.
const _maxParts = 4;

/// How many splits are kept per position, and returned overall.
const _maxSplits = 3;

/// Every substring [findSplits] might look up.
///
/// Splitting needs to know which slices of the word are headwords, and each
/// probe is a binary search. Handing the whole set to the caller lets every
/// dictionary answer them in one batch instead of one `await` per slice.
Set<String> splitCandidates(String word) {
  if (word.length > maxSplitLength || word.length < _minWordLength) {
    return const {};
  }

  final minLength = _minPartLength(word);
  final candidates = <String>{};
  for (var start = 0; start < word.length; start++) {
    for (var end = start + minLength; end <= word.length; end++) {
      // The whole word is what failed to match; it cannot be one of its own
      // parts, so there is no point probing it.
      if (start == 0 && end == word.length) continue;
      candidates.add(word.substring(start, end));
    }
  }
  return candidates;
}

/// Ways to read [word] as several headwords, best first, at most three.
///
/// [resolve] answers with the spelling the dictionary uses for a slice, or
/// null when no dictionary has it — that is what lets the result show `Cover`
/// for a query typed as `cover`.
List<WordSplit> findSplits(
  String word, {
  required String? Function(String candidate) resolve,
}) {
  if (word.length > maxSplitLength || word.length < _minWordLength) {
    return const [];
  }

  // The same slice is reached from several positions once linkers are in play;
  // memoising keeps that one map lookup instead of one callback per path.
  final cache = <String, String?>{};
  String? lookup(String candidate) {
    if (cache.containsKey(candidate)) return cache[candidate];
    return cache[candidate] = resolve(candidate);
  }

  final minLength = _minPartLength(word);
  final allowLinkers = _isLatinText(word);
  final end = word.length;
  final best = List<List<List<String>>?>.filled(end + 1, null);
  best[0] = [const <String>[]];

  for (var start = 0; start < end; start++) {
    final paths = best[start];
    if (paths == null) continue;

    for (final path in paths) {
      if (path.length >= _maxParts) continue;
      // A path that already holds the maximum parts must finish at the end.
      final isLastPart = path.length == _maxParts - 1;

      void extend(int partStart) {
        for (var partEnd = partStart + minLength; partEnd <= end; partEnd++) {
          if (isLastPart && partEnd != end) continue;
          final headword = lookup(word.substring(partStart, partEnd));
          if (headword == null) continue;
          _offer(best, partEnd, [...path, headword]);
        }
      }

      extend(start);

      if (!allowLinkers || start == 0) continue;
      for (final linker in _linkers) {
        if (!word.startsWith(linker, start)) continue;
        // The linker is swallowed: the next part starts after it, so
        // `Wohnzimmer|s|schrank` reads as two parts, not three.
        final partStart = start + linker.length;
        if (partStart < end) extend(partStart);
      }
    }
  }

  final splits = best[end];
  if (splits == null) return const [];

  return [
    for (final parts in splits)
      if (parts.length > 1) WordSplit(parts),
  ];
}

/// Records [parts] as a way to reach [index], keeping the best few.
void _offer(List<List<List<String>>?> best, int index, List<String> parts) {
  final paths = best[index] ??= <List<String>>[];
  for (final existing in paths) {
    if (_sameParts(existing, parts)) return;
  }

  paths
    ..add(parts)
    ..sort(_compareParts);
  if (paths.length > _maxSplits) {
    paths.removeRange(_maxSplits, paths.length);
  }
}

/// Fewer parts first, then longer parts first, then a stable tie-break.
int _compareParts(List<String> a, List<String> b) {
  if (a.length != b.length) return a.length.compareTo(b.length);
  for (var i = 0; i < a.length; i++) {
    final difference = b[i].length - a[i].length;
    if (difference != 0) return difference;
  }
  return a.join("\u0000").compareTo(b.join("\u0000"));
}

bool _sameParts(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Shortest a part may be.
///
/// Japanese and Chinese entries can be a single character, and a run of CJK
/// text has to be segmented. Alphabetic languages rarely store one-letter
/// headwords, and matching those would only produce noise such as `A + bend`.
int _minPartLength(String word) {
  for (final rune in word.runes) {
    if (rune >= 0x2E80) return 1;
  }
  return 2;
}

/// Whether [word] is written in the Latin alphabet, which is what the German
/// linking rules assume. A combining mark is allowed because an `ä` stored as
/// `a` + U+0308 must not turn the word into "not Latin".
bool _isLatinText(String word) {
  for (final rune in word.runes) {
    if (rune >= 0x41 && rune <= 0x5A) continue;
    if (rune >= 0x61 && rune <= 0x7A) continue;
    if (rune >= 0xC0 && rune <= 0x24F && rune != 0xD7 && rune != 0xF7) {
      continue;
    }
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    return false;
  }
  return word.isNotEmpty;
}

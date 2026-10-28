/// Turns a phrase nobody could look up into the headwords a dictionary may
/// actually store.
///
/// A phrasal verb is written apart in the sentence but stored together in the
/// dictionary, and so is a German separable verb — the two differ only in the
/// direction the parts are joined:
///
/// ```
/// picked the phone up   ->  pick up     (verb + particle, object in between)
/// rufe dich an          ->  anrufen    (particle at the end, verb in second place)
/// ```
///
/// No particle list is needed: the dictionary is the filter. `in the end`
/// produces `in end`, no dictionary has it, and the candidate disappears.
///
/// Two-word phrases are deliberately out of scope — `picked up` already resolves
/// through the morphology pass of the normal lookup, so only longer input
/// reaches this.
library;

/// Upper bound on the words worth considering.
///
/// A selected paragraph is not a phrasal verb, and every word costs one
/// `stems()` call plus two probes.
const maxPhraseWords = 12;

/// Longest candidate worth probing, in characters.
const _maxCandidateLength = 40;

/// Shortest phrase this handles.
///
/// Two words already resolve in the normal lookup: `picked up` becomes `pick up`
/// through the stems it already asks Hunspell for.
const _minPhraseWords = 3;

/// The words of [phrase], with surrounding punctuation removed.
///
/// `„picked the phone up.“` and `picked  the phone up` both come out as four
/// clean tokens. Inner punctuation is kept: `pick-up` is one word, not two.
List<String> phraseTokens(String phrase) {
  const edgePunctuation = r"^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$";
  final pattern = RegExp(edgePunctuation, unicode: true);

  final tokens = <String>[];
  for (final raw in phrase.split(RegExp(r"\s+"))) {
    final token = raw.replaceAll(pattern, "");
    if (token.isNotEmpty) tokens.add(token);
  }
  return tokens;
}

/// Headwords [tokens] might be, most plausible first.
///
/// [stemsOf] answers with the base forms of a token, most faithful first; an
/// empty answer means "use the token as written", which is what happens when no
/// morphology is loaded.
///
/// Every token except the last is paired with the last one, because the verb is
/// not necessarily the first word: `I picked the phone up` starts with a
/// pronoun, and `Ich rufe dich an` puts the verb second.
List<String> phraseCandidates(
  List<String> tokens, {
  required List<String> Function(String token) stemsOf,
}) {
  if (tokens.length < _minPhraseWords || tokens.length > maxPhraseWords) {
    return const [];
  }

  final particle = tokens.last;
  final candidates = <String>[];
  void add(String candidate) {
    if (candidate.isEmpty || candidate.length > _maxCandidateLength) return;
    if (candidates.contains(candidate)) return;
    candidates.add(candidate);
  }

  for (var i = 0; i < tokens.length - 1; i++) {
    final head = tokens[i];
    // The base form before the spelling that was typed: `picked up` is stored
    // as `pick up`, while `picked up` itself is rarely a headword.
    for (final base in [...stemsOf(head), head]) {
      // Only two of the four possible combinations are probed: verb then
      // particle as two words (English `pick up`) and particle then verb
      // glued together (German `anrufen`). The other two are attested —
      // Hungarian writes the prefix as its own word when a modal comes
      // between (`fel kell hívnom`), Turkish glues a following verb
      // (`yapıvermek`) — but neither can occur in the languages this app
      // ships dictionaries for, and generating them costs more than nothing:
      // `picked the phone up` would offer `pickup`, which is a real entry
      // (a noun) and the wrong answer. Add them here when a dictionary in
      // such a language is actually tested, not before.
      add("$base $particle");
      add("$particle$base");
    }
  }
  return candidates;
}

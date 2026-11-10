import "dart:convert";

import "package:flutter/foundation.dart";

/// A resolved in-dictionary link target: the headword plus an optional anchor.
///
/// The parsing rules below are mirrored exactly by the injected JS in
/// `entry_link_script.dart`; the two implementations must stay in step.
@immutable
class EntryLinkTarget {
  const EntryLinkTarget({required this.word, this.anchor});

  /// The headword, with `##` already unescaped; it may contain a literal `#`.
  final String word;

  /// The anchor inside the entry, or null when the link does not scroll.
  /// An empty [word] with a non-null anchor means "scroll the current entry".
  final String? anchor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntryLinkTarget && word == other.word && anchor == other.anchor;

  @override
  int get hashCode => Object.hash(word, anchor);

  @override
  String toString() => "EntryLinkTarget(word: $word, anchor: $anchor)";
}

/// Parses the part of an `entry://` / `bword://` link that follows the scheme.
///
/// Scanning left to right, `##` escapes one literal `#` and a lone `#`
/// separates the headword from the anchor:
///
/// | input           | word         | anchor   |
/// | --------------- | ------------ | -------- |
/// | `tag#sumeru`    | `tag`        | `sumeru` |
/// | `tag##sumeru`   | `tag#sumeru` | –        |
/// | `tag##sumeru#x` | `tag#sumeru` | `x`      |
/// | `tag###sumeru`  | `tag#`       | `sumeru` |
/// | `#foo`          | *(empty)*    | `foo`    |
/// | `##foo`         | `#foo`       | –        |
///
/// A link that ends on a lone `#` carries no anchor: the empty remainder would
/// describe a scroll target that does not exist.
EntryLinkTarget parseEntryLink(String raw) {
  if (raw.isEmpty) return const EntryLinkTarget(word: "");

  final word = StringBuffer();
  var index = 0;
  while (index < raw.length) {
    if (raw[index] != "#") {
      word.write(raw[index]);
      index++;
      continue;
    }

    // A doubled hash is one escaped literal hash.
    if (index + 1 < raw.length && raw[index + 1] == "#") {
      word.write("#");
      index += 2;
      continue;
    }

    // A lone hash starts the anchor; everything after it is the target.
    final anchor = raw.substring(index + 1);
    return EntryLinkTarget(
      word: word.toString(),
      anchor: anchor.isEmpty ? null : anchor,
    );
  }

  return EntryLinkTarget(word: word.toString());
}

String _percentEncodeAll(String value) {
  final encoded = <String>[];
  for (final byte in utf8.encode(value)) {
    encoded.add("%${byte.toRadixString(16).padLeft(2, "0").toUpperCase()}");
  }
  return encoded.join();
}

/// The canonical `gdlookup://` href for a parsed link, or an empty string when
/// there is no headword to look up.
///
/// The anchor rides as a `?gdanchor=` query item, never as a fragment: a `#`
/// in a URL is a same-document position, so a fragment would be swallowed
/// before the navigation handler ever sees it.
String entryLinkHref(EntryLinkTarget target) {
  if (target.word.isEmpty) return "";
  final href = StringBuffer(
    "gdlookup://localhost/${_percentEncodeAll(target.word)}",
  );
  final anchor = target.anchor;
  if (anchor != null && anchor.isNotEmpty) {
    href.write("?gdanchor=${_percentEncodeAll(anchor)}");
  }
  return href.toString();
}

/// The canonical `sound://` href for a dictionary audio resource.
///
/// The file name moves into the path and is percent-encoded byte by byte:
/// names may contain `:`, `@`, `#`, `?` or upper-case ASCII, all of which a
/// URI parser would otherwise mangle.
String soundLinkHref(String file) =>
    "sound://localhost/${_percentEncodeAll(file)}";

final _bwordHrefPattern = RegExp(
  r'''(href\s*=\s*)(["'])bword://([^"']*)\2''',
  caseSensitive: false,
);

final _soundUrlPattern = RegExp(
  r'''((?:href|src)\s*=\s*)(["'])sound://([^"']*)\2''',
  caseSensitive: false,
);

/// Rewrites the two dictionary link shapes whose payload the URL parser
/// mangles, before the page is loaded:
///
/// * Babylon cross references, `bword://Word` → `gdlookup://localhost/<word>`
/// * audio references, `sound://FILE.spx` → `sound://localhost/<file>`
///
/// Both move the payload out of the **host** and into the path, because hosts
/// are folded to lower case on the way through the URL parser: `entry://Abend`
/// arrives as `abend`, and `sound://ID4107451.spx` arrives as
/// `id4107451_287466265.spx`, which matches neither a headword nor an `.mdd`
/// resource. Names that happen to be all lower case or all digits survive the
/// folding, which is why only some dictionaries were affected — and why the
/// same file plays in one dictionary and stays silent in the next.
///
/// A lone `#` in a Babylon link separates the headword from an anchor and `##`
/// escapes a literal `#`; see [parseEntryLink].
String normalizeDictionaryUrls(String html) {
  var result = html;

  if (result.toLowerCase().contains("bword:")) {
    result = result.replaceAllMapped(_bwordHrefPattern, (match) {
      final href = entryLinkHref(parseEntryLink(match[3] ?? ""));
      if (href.isEmpty) return match[0] ?? "";
      return '${match[1]}"$href"';
    });
  }

  if (result.toLowerCase().contains("sound://")) {
    result = result.replaceAllMapped(_soundUrlPattern, (match) {
      final file = (match[3] ?? "").split("#").first;
      if (file.isEmpty) return match[0] ?? "";
      // Already normalised: a second pass would encode the `localhost/` prefix
      // into the file name.
      if (file.toLowerCase().startsWith("localhost/")) return match[0] ?? "";
      return '${match[1]}"${soundLinkHref(file)}"';
    });
  }

  return result;
}

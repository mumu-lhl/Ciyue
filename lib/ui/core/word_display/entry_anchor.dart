import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

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

/// A pending "scroll this entry to this anchor" request.
typedef PendingAnchor = ({String word, String anchor});

/// The anchor the next rendered entry should scroll to, if any.
///
/// This is a one-shot request rather than navigation state, so it deliberately
/// stays out of the tab history: [WordTab] / [WordTabEntry] are left alone and
/// going back never re-triggers a scroll.
class PendingAnchorNotifier extends Notifier<PendingAnchor?> {
  @override
  PendingAnchor? build() => null;

  void request(String word, String anchor) {
    state = (word: word, anchor: anchor);
  }

  void clear() => state = null;
}

final pendingAnchorProvider =
    NotifierProvider<PendingAnchorNotifier, PendingAnchor?>(
      PendingAnchorNotifier.new,
    );

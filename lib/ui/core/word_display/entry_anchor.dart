import "package:flutter_riverpod/flutter_riverpod.dart";

export "package:ciyue/models/dictionary_links.dart"
    show EntryLinkTarget, parseEntryLink;

/// A pending "scroll this entry to this anchor" request.
///
/// [dictId] pins the request to the dictionary the link came from: one headword
/// can be answered by several dictionaries of a group, and the anchor id only
/// exists in the entry that defined it. Without the pin, a sibling dictionary
/// rendering the same headword at the same time could claim and drop the
/// request before the intended entry has even loaded.
typedef PendingAnchor = ({String word, String anchor, int dictId});

/// The anchor the next rendered entry should scroll to, if any.
///
/// This is a one-shot request rather than navigation state, so it deliberately
/// stays out of the tab history: [WordTab] / [WordTabEntry] are left alone and
/// going back never re-triggers a scroll.
class PendingAnchorNotifier extends Notifier<PendingAnchor?> {
  @override
  PendingAnchor? build() => null;

  /// Records the anchor [word] should scroll to once it renders in [dictId].
  ///
  /// Every entry navigation reports in, with a null [anchor] for a link that
  /// does not scroll. That clear-on-navigate keeps a request the previous page
  /// never used from being applied to a later visit of the same word.
  void request({
    required String word,
    required int? dictId,
    required String? anchor,
  }) {
    if (anchor == null || anchor.isEmpty || dictId == null) {
      state = null;
      return;
    }
    state = (word: word, anchor: anchor, dictId: dictId);
  }

  void clear() => state = null;
}

final pendingAnchorProvider =
    NotifierProvider<PendingAnchorNotifier, PendingAnchor?>(
      PendingAnchorNotifier.new,
    );

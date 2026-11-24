import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/desktop_selection_xtest.dart";
import "package:ciyue/utils.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// Acquires the text the user currently has selected in another application.
///
/// Every implementation returns trimmed non-empty text, or null when it can
/// tell there is no selection. Null means "definitely no selection": the
/// ladder stops there instead of falling through to the clipboard rung,
/// which could only return stale text the user never selected.
///
/// A provider that cannot tell whether a selection exists — a timeout, a
/// bus error, a missing channel — throws [SelectionUnavailableException]
/// instead of returning null, so the ladder can try the next rung. Any
/// other error is also treated as "try the next rung" by the ladder, so a
/// lookup hotkey can never crash the app from a broken provider.
abstract class SelectionTextProvider {
  Future<String?> getSelectedText();
}

/// Thrown by a selection provider that cannot determine whether a selection
/// exists, as opposed to returning null ("definitely no selection"). The
/// ladder catches this and tries the next rung.
class SelectionUnavailableException implements Exception {
  const SelectionUnavailableException([this.message]);

  final String? message;

  @override
  String toString() =>
      "SelectionUnavailableException${message == null ? "" : ": $message"}";
}

/// Reads the system clipboard. Pure Flutter, so it works on all three
/// desktops — and on its own it can only see text the user (or another app)
/// already copied.
class ClipboardSelectionProvider implements SelectionTextProvider {
  const ClipboardSelectionProvider();

  @override
  Future<String?> getSelectedText() async {
    try {
      final text = (await Clipboard.getData("text/plain"))?.text?.trim();
      return (text == null || text.isEmpty) ? null : text;
    } catch (error, stackTrace) {
      talker.error("Failed to read the clipboard", error, stackTrace);
      return null;
    }
  }
}

/// Turns an X11 selection into clipboard text by faking a Ctrl+C, then reads
/// it through [inner]. Linux X11 only — the ladder never constructs this
/// anywhere else.
///
/// A synthetic copy copies whatever the focused application offers,
/// including a password field: the X11 selection protocol carries no
/// information about the source, so this provider cannot tell one from a
/// text field. The only protection on this path is the call sites checking
/// the focused application against the user's exclusion list before
/// acquiring any text (`LookupHotkeyService.handleHotKey`,
/// `LookupBubbleService`).
class SyntheticCopySelectionProvider implements SelectionTextProvider {
  SyntheticCopySelectionProvider({
    required this.inner,
    required this.copyKeySender,
    this.pollInterval = const Duration(milliseconds: 50),
    this.pollTimeout = const Duration(milliseconds: 400),
  });

  final SelectionTextProvider inner;
  final CopyKeySender copyKeySender;

  /// How often to re-read the clipboard while waiting for the copy to land.
  final Duration pollInterval;

  /// How long to wait for the clipboard to change before giving up.
  final Duration pollTimeout;

  @override
  Future<String?> getSelectedText() async {
    // Whether the pre-copy clipboard was read successfully, whether this
    // lookup changed the clipboard, and what the copy produced. The
    // restore in the finally block runs only when there is something to
    // restore to (savedText != null) and this lookup actually changed the
    // clipboard: otherwise restoring would blank content that was never
    // captured (an image, a file) or never touched (a failed copy).
    var saved = false;
    String? savedText;
    var cleared = false;
    var modified = false;
    String? copiedText;
    try {
      savedText = (await Clipboard.getData("text/plain"))?.text;
      saved = true;
      final savedTrimmed = savedText?.trim();

      // Clear the clipboard first when it holds text: otherwise a copy
      // that writes back the same text is indistinguishable from no copy
      // at all, and the poll below times out. No text saved means nothing
      // to collide with (and nothing to restore), so an image or file is
      // left alone instead of being blanked.
      if (savedText != null) {
        await Clipboard.setData(const ClipboardData(text: ""));
        cleared = true;
        modified = true;
      }

      if (!await copyKeySender.sendCopy()) {
        throw const SelectionUnavailableException(
          "copy keystroke was not sent",
        );
      }

      final deadline = DateTime.now().add(pollTimeout);
      while (true) {
        final current = await inner.getSelectedText();
        if (current != null && (cleared || current != savedTrimmed)) {
          copiedText = current;
          modified = true;
          return current;
        }
        if (!DateTime.now().isBefore(deadline)) return null;
        await Future.delayed(pollInterval);
      }
    } on SelectionUnavailableException {
      rethrow;
    } catch (error, stackTrace) {
      talker.error("Failed to acquire the selected text", error, stackTrace);
      throw SelectionUnavailableException("synthetic copy failed: $error");
    } finally {
      if (saved && modified && savedText != null) {
        await _restoreClipboardIfUnchanged(
          savedText: savedText,
          expectedText: copiedText ?? (cleared ? "" : savedText),
        );
      }
    }
  }

  /// Puts the user's clipboard back the way it was, but only when it still
  /// holds what this lookup wrote: the user (or another app) may have
  /// copied something new while the lookup was running, and overwriting
  /// that would destroy their copy. Best-effort: a failed restore is
  /// logged, never thrown.
  static Future<void> _restoreClipboardIfUnchanged({
    required String savedText,
    required String expectedText,
  }) async {
    try {
      final current = (await Clipboard.getData("text/plain"))?.text;
      if ((current ?? "").trim() != expectedText.trim()) return;
      await Clipboard.setData(ClipboardData(text: savedText));
    } catch (error, stackTrace) {
      talker.warning(
        "Failed to restore the clipboard after synthetic copy",
        error,
        stackTrace,
      );
    }
  }
}

/// Single entry point for the selection-acquisition ladder, used by both the
/// popup service and the CLI branch.
///
/// The ladder tries each rung in platform order and returns the first text
/// found. A rung returning null means "definitely no selection", which
/// stops the ladder: falling through would only reach the clipboard rung,
/// which can return stale text the user never selected. A rung that cannot
/// tell throws [SelectionUnavailableException] and the next rung is tried.
///
/// * Linux X11: the X11 PRIMARY provider (Lane A), then the AT-SPI2
///   provider (Lane B), then the synthetic copy, then the clipboard.
/// * Linux Wayland: the AT-SPI2 provider (Lane B), then the clipboard —
///   a synthetic copy cannot work there, the compositor owns the keys.
/// * Windows/macOS: the native provider (Lane C), then the synthetic copy
///   with Lane C's sender, then the clipboard.
///
/// Note: the AT-SPI2 provider still reports every failure as null (its
/// implementation swallows bus errors), so on that rung a bus failure ends
/// the lookup instead of falling through. Making it throw
/// [SelectionUnavailableException] on bus errors is a follow-up for that
/// provider; the exception type exists for exactly that.
class SelectionTextProviders {
  SelectionTextProviders._();

  /// Lane A's X11 PRIMARY provider, installed at startup when available.
  static SelectionTextProvider? x11PrimaryProvider;

  /// Lane B's AT-SPI2 provider, installed at startup when available.
  static SelectionTextProvider? atspiProvider;

  /// Lane C's native Windows/macOS provider, installed at startup when
  /// available.
  static SelectionTextProvider? nativeDesktopProvider;

  /// Lane C's native copy sender for the Windows/macOS synthetic-copy rung,
  /// installed at startup when available.
  static CopyKeySender? nativeCopySender;

  static Future<String?> acquire() async {
    try {
      return await acquireRungs(_buildLadder());
    } catch (error, stackTrace) {
      talker.error("Failed to acquire the selected text", error, stackTrace);
      return null;
    }
  }

  /// Runs [rungs] in order and returns the first text found. A null from a
  /// rung stops the ladder (see the class doc); an unavailable rung falls
  /// through to the next one. Never throws: a failure of the whole ladder
  /// is null.
  @visibleForTesting
  static Future<String?> acquireRungs(List<SelectionTextProvider> rungs) async {
    for (final rung in rungs) {
      try {
        // Null means "definitely no selection": stop here instead of
        // falling through to the clipboard rung and its stale text.
        return await rung.getSelectedText();
      } on SelectionUnavailableException catch (error, stackTrace) {
        talker.warning(
          "Selection provider unavailable, trying the next rung",
          error,
          stackTrace,
        );
      } catch (error, stackTrace) {
        talker.warning(
          "Selection provider failed, trying the next rung",
          error,
          stackTrace,
        );
      }
    }
    return null;
  }

  static List<SelectionTextProvider> _buildLadder() {
    return buildLadder(
      isLinux: Platform.isLinux,
      isWindows: Platform.isWindows,
      isMacOS: Platform.isMacOS,
      isWayland: isWaylandSession(),
      xtestAvailable: XTestCopyKeySender.isAvailable,
      x11Primary: x11PrimaryProvider,
      atspi: atspiProvider,
      nativeProvider: nativeDesktopProvider,
      nativeCopySender: nativeCopySender,
    );
  }

  /// Builds the ordered rungs for the given platform. The slots are already
  /// availability-filtered by the startup wiring (a null slot means that
  /// lane's provider is absent or unavailable), so this only decides the
  /// order. The platform is a parameter (rather than read from [Platform])
  /// so the per-platform order is assertable in tests.
  @visibleForTesting
  static List<SelectionTextProvider> buildLadder({
    required bool isLinux,
    required bool isWindows,
    required bool isMacOS,
    required bool isWayland,
    required bool xtestAvailable,
    SelectionTextProvider? x11Primary,
    SelectionTextProvider? atspi,
    SelectionTextProvider? nativeProvider,
    CopyKeySender? nativeCopySender,
  }) {
    const clipboard = ClipboardSelectionProvider();
    SelectionTextProvider syntheticCopy(CopyKeySender sender) =>
        SyntheticCopySelectionProvider(inner: clipboard, copyKeySender: sender);

    final rungs = <SelectionTextProvider>[];
    if (isLinux) {
      if (isWayland) {
        if (atspi != null) rungs.add(atspi);
        rungs.add(clipboard);
        return rungs;
      }
      if (x11Primary != null) rungs.add(x11Primary);
      if (atspi != null) rungs.add(atspi);
      if (xtestAvailable) rungs.add(syntheticCopy(const XTestCopyKeySender()));
      rungs.add(clipboard);
      return rungs;
    }
    if (isWindows || isMacOS) {
      if (nativeProvider != null) rungs.add(nativeProvider);
      if (nativeCopySender != null) {
        rungs.add(syntheticCopy(nativeCopySender));
      }
      rungs.add(clipboard);
      return rungs;
    }
    return [clipboard];
  }
}

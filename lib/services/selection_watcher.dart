/// Contracts for watching the system selection and resolving the focused
/// application, shared by the Phase 2 lanes (issue #909).
///
/// Lane A implements the X11 (XFixes) watcher and resolver, Lane B the
/// AT-SPI2 pair, Lane C the Windows/macOS pair. The bubble service only
/// depends on these shapes, never on a lane's concrete class.
abstract class SelectionWatcher {
  /// Whether this watcher can run in the current process at all.
  bool get isAvailable;

  /// Fires when the system selection changes: true when a selection
  /// appeared, false when it was cleared. Never fires without a user-made
  /// selection change; there is no polling behind it.
  ///
  /// [stop] closes this stream. A watcher that is started again exposes
  /// a fresh stream, so subscribe to [onSelectionChanged] after [start]
  /// when reusing an instance.
  Stream<bool> get onSelectionChanged;

  Future<void> start();

  Future<void> stop();
}

/// Resolves the application that currently holds the input focus.
///
/// Returns the X11 WM_CLASS on Linux, the process name on Windows, the
/// bundle id on macOS — or null when it cannot be determined.
abstract class FocusedAppResolver {
  Future<String?> getFocusedAppId();
}

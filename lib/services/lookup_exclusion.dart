/// Which apps the desktop lookup popup stays silent for (issue #909).
///
/// Pure matching over the ids the platform reports (WM_CLASS on X11, bundle
/// id on macOS, process name on Windows): no platform calls happen here, so
/// the rules are unit-testable and the hotkey handler can apply them to
/// whatever id the focused-app resolver returns.
class LookupExclusionService {
  LookupExclusionService._();

  /// Whether the focused app, identified by [appId], is excluded by
  /// [patterns] (the user's `lookupExcludedApps` setting).
  ///
  /// A null or blank id is never excluded: an unknown app is not a reason to
  /// swallow a lookup. Otherwise a pattern matches when it equals the id or
  /// is contained in it, case-insensitively; blank patterns never match.
  static bool isExcluded(String? appId, List<String> patterns) {
    if (appId == null || appId.trim().isEmpty) return false;
    final id = appId.trim().toLowerCase();
    for (final pattern in patterns) {
      final needle = pattern.trim().toLowerCase();
      if (needle.isEmpty) continue;
      if (id == needle || id.contains(needle)) return true;
    }
    return false;
  }

  /// Whether [appId] looks like Ciyue itself: a WM_CLASS, bundle id, or
  /// process name containing "ciyue", case-insensitively. Selections made
  /// inside Ciyue are not foreign text, so the bubble watcher skips them.
  static bool isOwnApp(String? appId) {
    if (appId == null || appId.isEmpty) return false;
    return appId.toLowerCase().contains("ciyue");
  }
}

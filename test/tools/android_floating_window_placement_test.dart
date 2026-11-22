import "dart:io";

import "package:ciyue/services/floating_window_preferences.dart";
import "package:flutter_test/flutter_test.dart";

/// Pins the parts of the native placement that the Dart side cannot test.
///
/// The Android side reads these files before the Flutter engine exists, so the
/// two implementations can only be kept in step by their shared literals.
void main() {
  const kotlin = "android/app/src/main/kotlin/org/eu/mumulhl/ciyue";

  final settings = File("$kotlin/FloatingWindowSettings.kt").readAsStringSync();
  final activity = File("$kotlin/FloatingWindowActivity.kt").readAsStringSync();

  test("both sides read the same position file", () {
    expect(
      settings,
      contains('POSITION_FILE = "$floatingWindowPositionFileName"'),
    );
  });

  test("the native enum covers every position Dart can write", () {
    final body = RegExp(r"enum class Position\([^)]*\)\s*\{([\s\S]*?)\n    \}")
        .firstMatch(settings)
        ?.group(1);
    expect(
      body,
      isNotNull,
      reason: "FloatingWindowSettings.Position not found",
    );

    final nativeValues = RegExp(r'"([a-z_]+)"')
        .allMatches(body!)
        .map((match) => match.group(1))
        .toSet();

    for (final position in FloatingWindowPosition.values) {
      expect(
        nativeValues,
        contains(position.value),
        reason: "FloatingWindowSettings.Position is missing ${position.value}",
      );
    }
  });

  test("the popup is aligned inside the reader's band", () {
    expect(activity, contains("FloatingWindowSettings.readPosition(this)"));
    expect(activity, contains("bandTop"));
    // The window used to be forced to the left edge and offset by the reader's
    // margins, which made every position collapse to the top/bottom left.
    expect(activity, isNot(contains("geometry.gravity or Gravity.START")));
    expect(activity, isNot(contains("geometry.marginLeft")));
  });

  test("the popup is clamped to the area it may occupy", () {
    expect(activity, contains("displayWidth - width"));
    expect(activity, contains("displayHeight - height"));
    expect(activity, contains("coerceIn(0, (displayWidth - width)"));
  });

  test("the popup stays out of the system bars", () {
    // A window reaching under the status or navigation bar loses that strip:
    // the Flutter view is clipped there and nothing paints it (issue #905).
    expect(activity, contains("WindowInsets.Type.systemBars()"));
    expect(activity, contains("r.inset(i.left, i.top, i.right, i.bottom)"));
  });
}

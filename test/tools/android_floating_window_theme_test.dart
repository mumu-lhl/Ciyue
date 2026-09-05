import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  const resources = "android/app/src/main/res";

  String? styleItem(String source, String style, String item) {
    final body = RegExp('<style\\s+name="$style"[^>]*>([\\s\\S]*?)</style>')
        .firstMatch(source)
        ?.group(1);
    return body == null
        ? null
        : RegExp('<item name="$item">([^<]+)</item>')
              .firstMatch(body)
              ?.group(1);
  }

  test("floating Activity uses the checked transparent theme", () {
    final manifest = File("android/app/src/main/AndroidManifest.xml")
        .readAsStringSync();
    final activity = RegExp(
      r'<activity\s[^>]*android:name="\.FloatingWindowActivity"[^>]*>',
    ).firstMatch(manifest)?.group(0);
    expect(activity, contains('android:theme="@style/Theme.Transparent"'));
  });

  // WebView derives prefers-color-scheme from the native isLightTheme,
  // independently of Flutter's algorithmicDarkeningAllowed setting.
  // Theme.Translucent.NoTitleBar inherits false, even in values (day).
  for (final night in [false, true]) {
    for (final api31 in [false, true]) {
      final qualifier =
          "values${night ? "-night" : ""}"
          "${api31 ? "-v31" : ""}";
      test("floating WebView matches main theme in $qualifier", () {
        final base = File("$resources/values/styles.xml").readAsStringSync();
        final selected = File("$resources/$qualifier/styles.xml")
            .readAsStringSync();
        // Android selects a whole style, falling back to values when absent.
        final floatingSource = selected.contains('name="Theme.Transparent"')
            ? selected
            : base;
        final value = styleItem(
          floatingSource,
          "Theme.Transparent",
          "android:isLightTheme",
        );
        expect(value, "@bool/floating_window_is_light_theme");
        final bools = File(
          "$resources/${night ? "values-night" : "values"}/bools.xml",
        ).readAsStringSync();
        expect(
          bools,
          contains(
            '<bool name="floating_window_is_light_theme">${!night}</bool>',
          ),
        );
        expect(
          selected,
          contains(
            '<style name="NormalTheme" '
            'parent="@android:style/Theme.${night ? "Black" : "Light"}'
            '.NoTitleBar">',
          ),
        );
        expect(
          styleItem(
            floatingSource,
            "Theme.Transparent",
            "android:windowBackground",
          ),
          "@android:color/transparent",
        );
      });
    }
  }
}

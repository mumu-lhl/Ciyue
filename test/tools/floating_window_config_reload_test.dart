import "dart:io";

import "package:flutter_test/flutter_test.dart";

/// Pins the wiring that keeps the floating window's file-backed settings fresh.
///
/// The values live in files because the settings page and the floating engine
/// run in separate isolates, so every entry point that shows a lookup has to
/// read them again. They all have to go through one function: a value added to
/// only some of the paths is invisible until the engine restarts.
void main() {
  final platform = File("lib/services/platform.dart").readAsStringSync();
  final main = File("lib/main.dart").readAsStringSync();

  test("a lookup reloads the config before navigating", () {
    // 1: the processText method-channel handler, 2: the pending request that a
    // cold start consumes.
    expect(
      RegExp(r"await reloadFloatingWindowConfig\(\);")
          .allMatches(platform)
          .length,
      greaterThanOrEqualTo(2),
    );
    // Nothing may read the files on its own outside that function.
    expect(platform, isNot(contains("readPanelFraction()")));
    expect(platform, isNot(contains("readPosition()")));
  });

  test("the floating entrypoint reloads before the first build", () {
    // Scoped to the floating entrypoint: the main app has its own runApp.
    final entrypointAt = main.indexOf("void floatingWindow(");
    expect(entrypointAt, isNonNegative);
    final body = main.substring(entrypointAt);

    final reloadAt = body.indexOf("await reloadFloatingWindowConfig();");
    final runAppAt = body.indexOf(
      "runApp(const ProviderScope(child: Ciyue()));",
    );
    expect(reloadAt, isNonNegative);
    expect(runAppAt, isNonNegative);
    expect(
      reloadAt,
      lessThan(runAppAt),
      reason: "the first frame would otherwise draw the default position",
    );
  });
}

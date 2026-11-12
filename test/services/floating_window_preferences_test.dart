import "dart:io";

import "package:ciyue/services/floating_window_preferences.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late Directory directory;

  FloatingWindowPreferences store() =>
      FloatingWindowPreferences(directory: () async => directory);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp("ciyue-floating-window-");
    addTearDown(() => directory.delete(recursive: true));
  });

  test("defaults to the transparent panel", () async {
    expect(await store().readMode(), FloatingWindowMode.transparent);
  });

  test("migrates the legacy disable marker", () async {
    await File("${directory.path}/$floatingWindowLegacyDisabledFileName")
        .create();

    expect(await store().readMode(), FloatingWindowMode.off);
  });

  test("the mode file takes precedence over the legacy marker", () async {
    await File("${directory.path}/$floatingWindowLegacyDisabledFileName")
        .create();
    await store().writeMode(FloatingWindowMode.halfScreen);

    expect(await store().readMode(), FloatingWindowMode.halfScreen);
  });

  test("remembers the selected mode", () async {
    await store().writeMode(FloatingWindowMode.transparent);

    expect(await store().readMode(), FloatingWindowMode.transparent);
  });

  test("keeps the legacy marker in sync", () async {
    final marker = File(
      "${directory.path}/$floatingWindowLegacyDisabledFileName",
    );

    await store().writeMode(FloatingWindowMode.off);
    expect(await marker.exists(), isTrue);

    await store().writeMode(FloatingWindowMode.transparent);
    expect(await marker.exists(), isFalse);
  });

  test("unknown values fall back to the default", () async {
    await File("${directory.path}/$floatingWindowModeFileName")
        .writeAsString("something-new");

    expect(await store().readMode(), FloatingWindowMode.transparent);
  });

  test("parses the values written by the settings page", () {
    expect(
      FloatingWindowMode.parse(FloatingWindowMode.transparent.value),
      FloatingWindowMode.transparent,
    );
    expect(
      FloatingWindowMode.parse(FloatingWindowMode.halfScreen.value),
      FloatingWindowMode.halfScreen,
    );
    expect(
      FloatingWindowMode.parse(FloatingWindowMode.off.value),
      FloatingWindowMode.off,
    );
    expect(FloatingWindowMode.parse(null), FloatingWindowMode.transparent);
  });

  test("defaults to the built-in card size", () async {
    final fraction = await store().readPanelFraction();

    expect(fraction.width, FloatingWindowPanelFraction.defaultFraction.width);
    expect(fraction.height, FloatingWindowPanelFraction.defaultFraction.height);
  });

  test("remembers the card size", () async {
    await store().writePanelFraction(
      const FloatingWindowPanelFraction(width: 0.7, height: 0.6),
    );

    final fraction = await store().readPanelFraction();
    expect(fraction.width, 0.7);
    expect(fraction.height, 0.6);
  });

  test("clamps out-of-range card sizes", () async {
    await File("${directory.path}/$floatingWindowPanelFractionFileName")
        .writeAsString("1.5x0.1");

    final fraction = await store().readPanelFraction();
    expect(fraction.width, 1.0);
    expect(fraction.height, 0.4);
  });

  test("falls back on malformed card sizes", () async {
    await File("${directory.path}/$floatingWindowPanelFractionFileName")
        .writeAsString("oops");

    final fraction = await store().readPanelFraction();
    expect(fraction.width, FloatingWindowPanelFraction.defaultFraction.width);
    expect(fraction.height, FloatingWindowPanelFraction.defaultFraction.height);
  });
}

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
    await store().writeMode(FloatingWindowMode.halfScreen);

    expect(await store().readMode(), FloatingWindowMode.halfScreen);
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
}

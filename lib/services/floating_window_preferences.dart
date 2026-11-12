import "dart:io";

import "package:material_ui/material_ui.dart";
import "package:path_provider/path_provider.dart";

/// How a lookup launched from another app is shown on Android.
enum FloatingWindowMode {
  /// A centred card over a transparent window. The area around the card is
  /// the "tap outside to dismiss" target.
  transparent("transparent"),

  /// A dialog-style window covering part of the screen. The reader places it
  /// through the ColorDict intent extras so it avoids the selected word, and
  /// Dart fills the whole window so no transparent pixels are left for a
  /// multi-window compositor to paint black.
  halfScreen("half"),

  /// No floating window: open the main Activity instead.
  off("off");

  const FloatingWindowMode(this.value);

  final String value;

  static FloatingWindowMode parse(String? value) => switch (value) {
    "half" => FloatingWindowMode.halfScreen,
    "off" => FloatingWindowMode.off,
    _ => FloatingWindowMode.transparent,
  };
}

/// The mode of the current floating-window engine.
///
/// The settings page and the floating window run in separate isolates, so a
/// change there cannot notify this engine directly. Android sends the mode
/// along with every lookup instead.
final ValueNotifier<FloatingWindowMode> floatingWindowMode = ValueNotifier(
  FloatingWindowMode.transparent,
);

/// File names shared with FloatingWindowSettings.kt, which reads them before
/// the Flutter engine exists.
const floatingWindowModeFileName = "floating_window_mode";
const floatingWindowLegacyDisabledFileName = "disable_floating_window";

class FloatingWindowPreferences {
  FloatingWindowPreferences({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file(String name) async {
    final directory = await _directory();
    return File("${directory.path}/$name");
  }

  Future<FloatingWindowMode> readMode() async {
    final file = await _file(floatingWindowModeFileName);
    if (await file.exists()) {
      return FloatingWindowMode.parse((await file.readAsString()).trim());
    }

    // The old switch only knew on/off and expressed "off" with the presence
    // of an empty marker file. Keep those installations disabled.
    if (await (await _file(floatingWindowLegacyDisabledFileName)).exists()) {
      return FloatingWindowMode.off;
    }
    return FloatingWindowMode.transparent;
  }

  Future<void> writeMode(FloatingWindowMode mode) async {
    await (await _file(floatingWindowModeFileName)).writeAsString(mode.value);

    // Keep the legacy marker in sync so an older build reading only that
    // file still agrees with the new setting.
    final legacy = await _file(floatingWindowLegacyDisabledFileName);
    if (mode == FloatingWindowMode.off) {
      if (!await legacy.exists()) {
        await legacy.create();
      }
    } else if (await legacy.exists()) {
      await legacy.delete();
    }
  }
}

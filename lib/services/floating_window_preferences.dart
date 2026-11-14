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

/// Size of the popup as a fraction of the window.
///
/// In the transparent card mode this is the actual card size. In the
/// half-screen reader mode (ColorDict geometry) it is an upper bound: the
/// Android side caps the reader's requested popup at this size so a reader
/// asking for a full-width popup cannot cover more than the user picked.
class FloatingWindowPanelFraction {
  const FloatingWindowPanelFraction({
    required this.width,
    required this.height,
  });

  /// The default keeps the phone-sized card unchanged and makes a landscape
  /// card wider and lower, which is what the landscape layout wants.
  static const defaultFraction = FloatingWindowPanelFraction(
    width: 0.85,
    height: 0.55,
  );

  final double width;
  final double height;

  FloatingWindowPanelFraction copyWith({double? width, double? height}) =>
      FloatingWindowPanelFraction(
        width: width ?? this.width,
        height: height ?? this.height,
      );
}

/// The mode of the current floating-window engine.
///
/// The settings page and the floating window run in separate isolates, so a
/// change there cannot notify this engine directly. Android sends the mode
/// along with every lookup instead.
final ValueNotifier<FloatingWindowMode> floatingWindowMode = ValueNotifier(
  FloatingWindowMode.transparent,
);

/// The card size of the current floating-window engine.
///
/// The settings page writes it to a file; the floating engine reloads that
/// file on every lookup, so a change applies to the next lookup even when the
/// engine stays warm.
final ValueNotifier<FloatingWindowPanelFraction> floatingWindowPanelFraction =
    ValueNotifier(FloatingWindowPanelFraction.defaultFraction);

/// File names shared with FloatingWindowSettings.kt, which reads them before
/// the Flutter engine exists.
const floatingWindowModeFileName = "floating_window_mode";
const floatingWindowLegacyDisabledFileName = "disable_floating_window";
const floatingWindowPanelFractionFileName = "floating_window_panel_fraction";

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

  Future<FloatingWindowPanelFraction> readPanelFraction() async {
    final file = await _file(floatingWindowPanelFractionFileName);
    if (!await file.exists()) {
      return FloatingWindowPanelFraction.defaultFraction;
    }

    final parts = (await file.readAsString()).trim().split("x");
    if (parts.length != 2) {
      return FloatingWindowPanelFraction.defaultFraction;
    }
    final width = double.tryParse(parts[0]);
    final height = double.tryParse(parts[1]);
    if (width == null || height == null) {
      return FloatingWindowPanelFraction.defaultFraction;
    }
    return FloatingWindowPanelFraction(
      width: width.clamp(0.4, 1.0),
      height: height.clamp(0.4, 1.0),
    );
  }

  Future<void> writePanelFraction(FloatingWindowPanelFraction fraction) async {
    await (await _file(floatingWindowPanelFractionFileName))
        .writeAsString("${fraction.width}x${fraction.height}");
  }
}

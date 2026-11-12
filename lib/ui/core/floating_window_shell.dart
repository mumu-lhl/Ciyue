import "dart:async";
import "dart:math" as math;

import "package:ciyue/services/floating_window.dart";
import "package:ciyue/services/floating_window_preferences.dart";
import "package:material_ui/material_ui.dart";

/// The visible part of the Android floating window.
///
/// The Activity window spans the whole display; only [child] is drawn and the
/// transparent area around it is the tap target that dismisses the window.
class FloatingWindowShell extends StatelessWidget {
  const FloatingWindowShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(dismissFloatingWindow()),
          child: const SizedBox.expand(),
        ),
        Align(
          alignment: Alignment.center,
          child: ValueListenableBuilder<FloatingWindowPanelFraction>(
            valueListenable: floatingWindowPanelFraction,
            builder: (context, fraction, _) => LayoutBuilder(
              builder: (context, constraints) {
                final size = floatingWindowPanelSize(
                  constraints,
                  fraction: fraction,
                );
                return SizedBox(
                  width: size.width,
                  height: size.height,
                  child: child,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Smallest card the panel may shrink to. Without it a small percentage in a
/// narrow free-form window would make the dictionary text unreadable.
const minPanelWidth = 280.0;
const minPanelHeight = 240.0;

/// Panel geometry for [FloatingWindowShell].
///
/// [fraction] is the user's card size: width and height as a fraction of the
/// window, so the window itself is the only upper bound - a full 100% simply
/// covers the whole screen and is still dismissible with back. The readable
/// minimum wins over a tiny fraction, but a window smaller than the minimum
/// wins over both, so the card never overflows the window.
Size floatingWindowPanelSize(
  BoxConstraints constraints, {
  FloatingWindowPanelFraction fraction =
      FloatingWindowPanelFraction.defaultFraction,
}) {
  final maxWidth = constraints.maxWidth;
  final maxHeight = constraints.maxHeight;

  return Size(
    (maxWidth * fraction.width)
        .clamp(math.min(minPanelWidth, maxWidth), maxWidth)
        .toDouble(),
    (maxHeight * fraction.height)
        .clamp(math.min(minPanelHeight, maxHeight), maxHeight)
        .toDouble(),
  );
}

/// Reloads the card size from disk and notifies the panel.
///
/// The settings page writes the file from the main isolate; the floating
/// engine is a separate isolate, so it reads the file again on every lookup.
Future<void> reloadFloatingWindowPanelFraction() async {
  final preferences = FloatingWindowPreferences();
  floatingWindowPanelFraction.value = await preferences.readPanelFraction();
}

/// Wraps the dictionary view for the Android floating window.
///
/// Only the transparent mode needs the dismiss target around the card. The
/// half-screen mode fills its whole (opaque) window instead, so that no
/// transparent pixels are left for a multi-window compositor to paint black.
Widget floatingWindowView({required Widget child}) {
  return ValueListenableBuilder<FloatingWindowMode>(
    valueListenable: floatingWindowMode,
    builder: (context, mode, _) {
      if (mode != FloatingWindowMode.transparent) {
        return child;
      }
      return FloatingWindowShell(child: child);
    },
  );
}

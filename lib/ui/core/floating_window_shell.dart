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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = floatingWindowPanelSize(constraints);
              return SizedBox(
                width: size.width,
                height: size.height,
                child: child,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Panel geometry for [FloatingWindowShell].
///
/// Landscape windows are wide but short: spread the dictionary horizontally
/// and keep the panel low, so it stays readable without covering the whole
/// display or overflowing a short free-form window. Portrait keeps the
/// original compact, phone-shaped card.
Size floatingWindowPanelSize(BoxConstraints constraints) {
  final maxWidth = constraints.maxWidth;
  final maxHeight = constraints.maxHeight;

  final double width;
  final double height;
  if (maxWidth > maxHeight) {
    // 0.8 of the width, capped so the panel does not become a full-screen
    // card on tablets; 0.65 of the height leaves room for the transparent
    // dismiss area above and below on short landscape windows.
    width = math.min(maxWidth * 0.8, 900.0);
    height = math.min(maxHeight * 0.65, 560.0);
  } else {
    final isWide = maxWidth >= 600.0;
    width = isWide ? 540.0 : maxWidth * 0.85;
    height = isWide ? (maxHeight * 0.7).clamp(420.0, 720.0) : maxHeight * 0.55;
  }

  // Never let the hard limits exceed the window, e.g. a short landscape
  // window or a small free-form window.
  return Size(math.min(width, maxWidth), math.min(height, maxHeight));
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

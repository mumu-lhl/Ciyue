import "package:ciyue/repositories/settings.dart";
import "package:material_ui/material_ui.dart";

/// Motion helpers for the e-ink mode.
///
/// An e-ink panel keeps the previous image while the next one is drawn, so
/// every frame of an animation leaves a ghost behind. The mode therefore
/// removes motion only: colours, contrast and the dictionary styles are left
/// exactly as they are, because modern panels are colour panels.
bool get eInkMotionless => settings.eInkMode;

/// [duration], or zero while the e-ink mode is on.
Duration motionDuration(Duration duration) =>
    settings.eInkMode ? Duration.zero : duration;

/// A page transition that puts the destination page on screen immediately.
class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Every platform's page transition replaced by [NoAnimationPageTransitionsBuilder].
const noAnimationPageTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
    TargetPlatform.fuchsia: NoAnimationPageTransitionsBuilder(),
    TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
    TargetPlatform.linux: NoAnimationPageTransitionsBuilder(),
    TargetPlatform.macOS: NoAnimationPageTransitionsBuilder(),
    TargetPlatform.windows: NoAnimationPageTransitionsBuilder(),
  },
);

/// A circular progress indicator that stops spinning in the e-ink mode.
///
/// The spinner keeps redrawing for as long as its future runs, which is the
/// worst case for an e-ink panel; in that mode a static hourglass is shown
/// instead. Everywhere else this is exactly the indicator it replaces.
class EInkAwareSpinner extends StatelessWidget {
  final double? size;
  final double? strokeWidth;
  final Color? color;

  const EInkAwareSpinner({super.key, this.size, this.strokeWidth, this.color});

  @override
  Widget build(BuildContext context) {
    if (!eInkMotionless) {
      return CircularProgressIndicator(
        strokeWidth: strokeWidth ?? 4,
        color: color,
      );
    }
    final effectiveSize = size ?? 24;
    return Icon(
      Icons.hourglass_empty,
      size: effectiveSize,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

/// A linear progress indicator that stops moving in the e-ink mode.
///
/// Without a [value] the bar animates forever; the e-ink mode falls back to a
/// plain static rule so the panel is not repainted for nothing.
class EInkAwareProgressBar extends StatelessWidget {
  final double? value;
  final double minHeight;

  const EInkAwareProgressBar({super.key, this.value, this.minHeight = 4});

  @override
  Widget build(BuildContext context) {
    if (!eInkMotionless) {
      return LinearProgressIndicator(value: value, minHeight: minHeight);
    }
    return SizedBox(
      height: minHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(minHeight / 2),
        ),
      ),
    );
  }
}

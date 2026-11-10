import "dart:async";

import "package:flutter/widgets.dart";

/// A long press that the page scroll cannot take away.
///
/// A `GestureDetector` long press competes with the scroll recognizer of the
/// page in the gesture arena, and the scroll recognizer accepts as soon as
/// the finger has moved a little. Holding a button on a touch screen always
/// drifts by a few pixels, so on Android the long press is usually lost before
/// it ever fires, while a mouse on the desktop hardly moves at all and the
/// same gesture works there.
///
/// Listening to the raw pointer events keeps the gesture out of the arena, so
/// the press survives the scroll. The tap is left to the child, which is why
/// [onPressStart] exists: it tells the child that a new press began, so it can
/// forget about a long press that has already been handled.
class LongPressDetector extends StatefulWidget {
  const LongPressDetector({
    super.key,
    required this.onPressStart,
    required this.onLongPress,
    this.timeout = const Duration(milliseconds: 350),
    this.slop = 30.0,
    required this.child,
  });

  /// Called when a new press starts, before a long press is possible.
  final VoidCallback onPressStart;

  /// Called when the child is held down for [timeout].
  final VoidCallback onLongPress;

  final Duration timeout;

  /// How far the finger may drift before the press stops counting as a long
  /// press. A finger never stays perfectly still, so this is more forgiving
  /// than the touch slop the scroll recognizer uses.
  final double slop;

  final Widget child;

  @override
  State<LongPressDetector> createState() => _LongPressDetectorState();
}

class _LongPressDetectorState extends State<LongPressDetector> {
  Timer? _timer;
  Offset? _origin;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleDown(PointerDownEvent event) {
    _origin = event.position;
    _timer?.cancel();
    widget.onPressStart();
    _timer = Timer(widget.timeout, widget.onLongPress);
  }

  void _handleMove(PointerMoveEvent event) {
    final origin = _origin;
    if (origin == null) return;
    if ((event.position - origin).distance > widget.slop) {
      _timer?.cancel();
    }
  }

  void _handleUp(PointerEvent event) {
    _timer?.cancel();
    _origin = null;
  }

  void _handleCancel(PointerCancelEvent event) {
    _timer?.cancel();
    _origin = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: _handleUp,
      onPointerCancel: _handleCancel,
      child: widget.child,
    );
  }
}

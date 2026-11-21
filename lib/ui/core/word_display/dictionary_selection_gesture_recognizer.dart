import "dart:async";

import "package:flutter/gestures.dart";

/// Lets a touch drag inside the dictionary WebView mean either "switch tab"
/// or "select text", depending on whether the reader held first.
///
/// Mouse presses are claimed immediately: left-button dragging is how text is
/// selected on desktop. Touch presses wait briefly; if the finger moves before
/// the timer fires the gesture is rejected so an enclosing PageView can switch
/// dictionary tabs, otherwise it is accepted and the WebView owns the drag.
class DictionarySelectionGestureRecognizer
    extends OneSequenceGestureRecognizer {
  DictionarySelectionGestureRecognizer({
    this.holdDuration = const Duration(milliseconds: 400),
  });

  final Duration holdDuration;

  Timer? _timer;
  Offset? _start;
  int? _pointer;
  bool _accepted = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointer = event.pointer;
    _start = event.localPosition;
    _accepted = false;
    _timer?.cancel();

    if (event.kind == PointerDeviceKind.mouse) {
      _accepted = true;
      resolve(GestureDisposition.accepted);
      return;
    }

    _timer = Timer(holdDuration, () {
      if (_pointer == null) return;
      _accepted = true;
      resolve(GestureDisposition.accepted);
    });
  }

  @override
  void handleEvent(PointerEvent event) {
    if (_pointer != event.pointer) return;

    if (!_accepted &&
        event is PointerMoveEvent &&
        _start != null &&
        (event.localPosition - _start!).distance > 8) {
      _timer?.cancel();
      resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
      return;
    }

    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _timer?.cancel();
      if (!_accepted) resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _timer?.cancel();
    _pointer = null;
    _start = null;
  }

  @override
  String get debugDescription => "dictionary selection";
}

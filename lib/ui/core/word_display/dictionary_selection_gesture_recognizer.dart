import "package:flutter/gestures.dart";

/// Keeps mouse dragging inside the dictionary WebView instead of letting an
/// enclosing PageView turn it into a dictionary-tab swipe.
///
/// Touch is deliberately rejected: on a touch screen a drag should still page
/// between dictionaries, and the mouse selection fallback in
/// `textSelectionScript` does not handle touch input.
class DictionarySelectionGestureRecognizer
    extends OneSequenceGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (event.kind == PointerDeviceKind.mouse) {
      resolve(GestureDisposition.accepted);
    } else {
      resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => "dictionary mouse selection";
}

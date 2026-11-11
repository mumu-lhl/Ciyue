import "package:flutter/gestures.dart";

/// Detects the right-button edge of a chorded mouse press on Windows.
///
/// Flutter never sends a second `PointerDownEvent` while another button is
/// held: the new button shows up only in the `buttons` bitmask of a later
/// pointer event. The Windows WebView plugin forwards pointer moves as cursor
/// positions only, so WebView2 never sees a `mousedown` for that second button
/// and the injected gesture script cannot see a rocker.
///
/// Watching Flutter's own bitmask outside the WebView and telling the script
/// about the edge avoids forking the plugin. Whether the edge really is a
/// rocker (the left button has to be down) is decided in the script, which
/// also de-duplicates a press that arrives through more than one path.
///
/// [update] returns true once per press, on the right button's 0 -> 1 edge.
class WindowsRockerEdgeDetector {
  bool _rightDown = false;

  bool update(int buttons) {
    final rightDown = (buttons & kSecondaryMouseButton) != 0;
    final edge = rightDown && !_rightDown;
    _rightDown = rightDown;
    return edge;
  }
}

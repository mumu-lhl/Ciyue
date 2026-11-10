/// Desktop-only mouse gestures, forwarded to Dart through the key bridge.
///
/// * Rocker: hold the left button and click the right one. Only this direction
///   is supported, so the action has to be a cyclic one. The context menu is
///   suppressed *only* while the left button is down, which leaves an ordinary
///   right click untouched.
/// * Wheel: scroll while the left button is held. The wheel listener has to be
///   non-passive so `preventDefault()` can stop the page from scrolling. The
///   left button also starts a rocker gesture; the event type tells them apart.
///
/// `Ctrl` is excluded everywhere: on macOS Ctrl+left click is translated by the
/// system into a right click, and treating it as a gesture would swallow both
/// the menu and the reader's Ctrl+click-to-open-in-a-new-tab.
///
/// [bitmaskFallback] adds a `mousemove` listener that reads the right button
/// out of the event's button bitmask, and it is injected on Linux/WPE only.
///
/// Flutter never delivers a second `PointerDownEvent` for a chorded press: the
/// new button shows up only in `PointerMoveEvent.buttons`. The Linux platform
/// view forwards that edge to WPE, and this listener is a second net on top.
/// WebView2 (Windows) has no such forwarding — its `onPointerMove` only moves the
/// cursor, so the page often never sees the second button — and its `e.buttons`
/// reports the right bit as held even for a left-only press (notably once the
/// app's own context menu has opened), so reading the bitmask there turns a plain
/// left press into a false rocker. That is why the fallback stays off Windows.
///
/// Known limitation: without that forwarding the rocker on Windows is only
/// intermittent. Fixing it properly means forwarding the button edge in the
/// Windows plugin's `onPointerMove`, exactly as the Linux platform view does.
String gestureScript({bool bitmaskFallback = true}) {
  final bitmaskFallbackBlock = bitmaskFallback
      ? """
  // WPE can report an extra button only as a move event with an updated
  // bitmask, dispatching neither mousedown nor contextmenu for it.
  document.addEventListener('mousemove', function (e) {
    if (leftDown && !e.ctrlKey && (e.buttons & 2) !== 0) {
      sendRocker();
    }
  }, true);
"""
      : "";
  return """
(function () {
  function post(payload) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('ciyueKey', 'Gesture', payload);
    }
  }

  var leftDown = false;
  var rightDown = false;
  var suppressClick = false;
  var rockerSent = false;
  var lastWheelAt = 0;

  function send(kind, direction) {
    suppressClick = true;
    post(JSON.stringify({ kind: kind, direction: direction }));
  }

  function sendRocker() {
    // A right press can surface as mousedown, as contextmenu, or as the
    // move-event bitmask below. Send it exactly once per press.
    if (rockerSent) return;
    rockerSent = true;
    send('rocker', 1);
  }

  document.addEventListener('mousedown', function (e) {
    suppressClick = false;
    if (e.ctrlKey) return;
    if (e.button === 0) {
      leftDown = true;
      rockerSent = false;
    } else if (e.button === 2) {
      rightDown = true;
      if (leftDown) {
        e.preventDefault();
        e.stopPropagation();
        sendRocker();
      }
    }
  }, true);

  document.addEventListener('mouseup', function (e) {
    if (e.button === 0) leftDown = false;
    if (e.button === 2) rightDown = false;
  }, true);

  // A right press the engine reports only as contextmenu still counts, but a
  // touch or pen long press also fires contextmenu (with button 0) while the
  // primary button reads as held; that one must not be taken for the right
  // button, or a plain tap-and-hold would trigger the rocker.
  document.addEventListener('contextmenu', function (e) {
    if (leftDown && !e.ctrlKey && (e.button === 2 || rightDown)) {
      e.preventDefault();
      e.stopPropagation();
      sendRocker();
    }
  }, true);

$bitmaskFallbackBlock

  // A lost mouseup while the window is deactivated must not latch the buttons
  // on, or the next contextmenu would read as a rocker.
  window.addEventListener('blur', function () {
    leftDown = false;
    rightDown = false;
    rockerSent = false;
  });

  document.addEventListener('wheel', function (e) {
    // Holding the left button also starts a rocker gesture; the two are told
    // apart by the event type, not by the button.
    if (!leftDown) return;
    e.preventDefault();
    e.stopPropagation();
    // One physical scroll fires several wheel events, especially on a
    // trackpad; keep a gesture from stepping through several tabs at once.
    var now = Date.now();
    if (now - lastWheelAt < 80) return;
    lastWheelAt = now;
    send('wheel', e.deltaY > 0 ? 1 : -1);
  }, { capture: true, passive: false });

  // A gesture ends with the left button up, which may still dispatch a click
  // on a dictionary link. Swallow that one event.
  document.addEventListener('click', function (e) {
    if (!suppressClick) return;
    e.preventDefault();
    e.stopPropagation();
    suppressClick = false;
  }, true);
})();
""";
}

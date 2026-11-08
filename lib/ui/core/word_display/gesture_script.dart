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
String gestureScript() {
  return """
(function () {
  function post(payload) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('ciyueKey', 'Gesture', payload);
    }
  }

  var leftDown = false;
  var suppressClick = false;
  var rockerSent = false;
  var lastWheelAt = 0;

  function send(kind, direction) {
    suppressClick = true;
    post(JSON.stringify({ kind: kind, direction: direction }));
  }

  function sendRocker() {
    // Some WebViews only dispatch contextmenu for the right button, so both
    // paths can see the same press. Send it exactly once.
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
    } else if (e.button === 2 && leftDown) {
      e.preventDefault();
      e.stopPropagation();
      sendRocker();
    }
  }, true);

  document.addEventListener('mouseup', function (e) {
    if (e.button === 0) leftDown = false;
  }, true);

  document.addEventListener('contextmenu', function (e) {
    if (leftDown && !e.ctrlKey) {
      e.preventDefault();
      e.stopPropagation();
      sendRocker();
    }
  }, true);

  // WPE can report an extra button only as a move event with an updated
  // bitmask, dispatching neither mousedown nor contextmenu for it.
  document.addEventListener('mousemove', function (e) {
    if (leftDown && !e.ctrlKey && (e.buttons & 2) !== 0) {
      sendRocker();
    }
  }, true);

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

/// Desktop-only mouse gestures, forwarded to Dart through the key bridge.
///
/// * Rocker: hold the left button and click the right one. Only this direction
///   is supported, so the action has to be a cyclic one. The context menu is
///   suppressed *only* while the left button is down, which leaves an ordinary
///   right click untouched.
/// * Wheel: scroll while the middle button is held. The wheel listener has to
///   be non-passive so `preventDefault()` can stop the page from scrolling.
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
  var middleDown = false;
  var suppressClick = false;
  var lastWheelAt = 0;

  function send(kind, direction) {
    suppressClick = true;
    post(JSON.stringify({ kind: kind, direction: direction }));
  }

  document.addEventListener('mousedown', function (e) {
    suppressClick = false;
    if (e.ctrlKey) return;
    if (e.button === 0) {
      leftDown = true;
    } else if (e.button === 1) {
      middleDown = true;
      // Stop the browser's middle-button autoscroll.
      e.preventDefault();
    } else if (e.button === 2 && leftDown) {
      e.preventDefault();
      e.stopPropagation();
      send('rocker', 1);
    }
  }, true);

  document.addEventListener('mouseup', function (e) {
    if (e.button === 0) leftDown = false;
    if (e.button === 1) middleDown = false;
  }, true);

  document.addEventListener('contextmenu', function (e) {
    if (leftDown && !e.ctrlKey) {
      e.preventDefault();
      e.stopPropagation();
    }
  }, true);

  document.addEventListener('wheel', function (e) {
    if (!middleDown) return;
    e.preventDefault();
    e.stopPropagation();
    // One physical scroll fires several wheel events, especially on a
    // trackpad; keep a gesture from stepping through several tabs at once.
    var now = Date.now();
    if (now - lastWheelAt < 80) return;
    lastWheelAt = now;
    send('wheel', e.deltaY > 0 ? 1 : -1);
  }, { capture: true, passive: false });

  // The left button is released after a rocker gesture, so the browser may
  // still dispatch a click on a dictionary link. Swallow that one event.
  document.addEventListener('click', function (e) {
    if (!suppressClick) return;
    e.preventDefault();
    e.stopPropagation();
    suppressClick = false;
  }, true);

  document.addEventListener('auxclick', function (e) {
    if (!suppressClick || e.button !== 1) return;
    e.preventDefault();
    e.stopPropagation();
    suppressClick = false;
  }, true);
})();
""";
}

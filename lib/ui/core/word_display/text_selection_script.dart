/// Desktop text-selection fallback for the Linux/Windows WebViews.
///
/// WPE on KDE does not always turn pointer motion or a press-and-hold into a
/// DOM selection, and it can drop the word selection made by a double click on
/// mouse up. This script builds selections from `caretRangeFromPoint` itself:
///
/// * left drag extends from the press point to the current point;
/// * a 400 ms left/touch press-and-hold selects the word under the pointer;
/// * after a touch long press, dragging extends that selection and lifting the
///   finger opens the app's context menu with the final selected text;
/// * double-click and long-press selections are restored if the engine clears
///   them on release.
///
/// It never cancels an event, so the engine's own selection and the app's
/// context-menu/rocker handlers keep working.
String textSelectionScript() {
  return """
(function () {
  // Re-injected after every load so a document that replaced the original one
  // still exposes the hooks; installing twice would double the listeners.
  if (window.__ciyueTextSelectionInstalled) return;
  window.__ciyueTextSelectionInstalled = true;

  var anchor = null;
  var startX = 0;
  var startY = 0;
  var dragging = false;
  var mouseStart = null;
  var lastPressDetail = 0;
  var longPressSelected = false;
  var mouseLongPressTimer = 0;
  var touchStart = null;
  var touchLast = null;
  var touchAnchor = null;
  var touchLongPressFired = false;
  var touchLongPressTimer = 0;

  function postMenu(x, y) {
    var selection = window.getSelection();
    var word = selection ? selection.toString().trim() : '';
    if (!word) return;
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler(
        'ciyueKey',
        'DesktopContextMenu',
        JSON.stringify({ x: x, y: y, word: word })
      );
    }
  }

  function rangeAt(x, y) {
    return document.caretRangeFromPoint
        ? document.caretRangeFromPoint(x, y)
        : null;
  }

  function selectFrom(a, b) {
    if (!a || !b) return;
    var selection = window.getSelection();
    if (!selection) return;
    // caretRangeFromPoint returns a collapsed range at each end; keep the
    // earlier one as the start so dragging backwards works too.
    var forward = a.compareBoundaryPoints(Range.START_TO_START, b) <= 0;
    var first = forward ? a : b;
    var last = forward ? b : a;
    var range = document.createRange();
    range.setStart(first.startContainer, first.startOffset);
    range.setEnd(last.startContainer, last.startOffset);
    selection.removeAllRanges();
    selection.addRange(range);
  }

  function selectWordAt(x, y) {
    var range = rangeAt(x, y);
    var selection = window.getSelection();
    if (!range || !selection) return;
    selection.removeAllRanges();
    selection.addRange(range);
    if (selection.modify) {
      selection.modify('move', 'backward', 'word');
      selection.modify('extend', 'forward', 'word');
    }
  }

  function selectionEmpty() {
    var selection = window.getSelection();
    return !selection || selection.toString().trim() === '';
  }

  document.addEventListener('mousedown', function (e) {
    if (e.button !== 0 || e.shiftKey || e.ctrlKey || e.altKey || e.metaKey) {
      return;
    }
    anchor = rangeAt(e.clientX, e.clientY);
    startX = e.clientX;
    startY = e.clientY;
    dragging = anchor !== null;
    mouseStart = { x: e.clientX, y: e.clientY };
    lastPressDetail = e.detail || 1;
    longPressSelected = false;
    clearTimeout(mouseLongPressTimer);
    mouseLongPressTimer = setTimeout(function () {
      if (!mouseStart) return;
      selectWordAt(mouseStart.x, mouseStart.y);
      longPressSelected = true;
    }, 450);
  }, true);

  document.addEventListener('mousemove', function (e) {
    if (!mouseStart) return;
    if (Math.abs(e.clientX - startX) + Math.abs(e.clientY - startY) > 3) {
      clearTimeout(mouseLongPressTimer);
    }
    if (!dragging) return;
    if ((e.buttons & 1) === 0) {
      dragging = false;
      anchor = null;
      return;
    }
    if (Math.abs(e.clientX - startX) + Math.abs(e.clientY - startY) < 3) {
      return;
    }
    var current = rangeAt(e.clientX, e.clientY);
    if (current) selectFrom(anchor, current);
  }, true);

  function endMouse() {
    clearTimeout(mouseLongPressTimer);
    // Some engines build the double-click word selection on press but clear it
    // again on release; restore it from the same point.
    if (mouseStart &&
        selectionEmpty() &&
        (longPressSelected || lastPressDetail > 1)) {
      selectWordAt(mouseStart.x, mouseStart.y);
    }
    mouseStart = null;
    longPressSelected = false;
    dragging = false;
    anchor = null;
  }

  document.addEventListener('mouseup', endMouse, true);
  window.addEventListener('blur', function () {
    clearTimeout(mouseLongPressTimer);
    mouseStart = null;
    dragging = false;
    anchor = null;
  });

  document.addEventListener('touchstart', function (e) {
    if (e.touches.length !== 1) return;
    var touch = e.touches[0];
    touchStart = { x: touch.clientX, y: touch.clientY };
    touchLast = touchStart;
    touchAnchor = null;
    touchLongPressFired = false;
    clearTimeout(touchLongPressTimer);
    touchLongPressTimer = setTimeout(function () {
      if (!touchStart) return;
      touchAnchor = rangeAt(touchStart.x, touchStart.y);
      selectWordAt(touchStart.x, touchStart.y);
      touchLongPressFired = true;
    }, 400);
  }, true);

  document.addEventListener('touchmove', function (e) {
    if (!touchStart || e.touches.length !== 1) return;
    var touch = e.touches[0];
    touchLast = { x: touch.clientX, y: touch.clientY };
    if (!touchLongPressFired) {
      if (Math.abs(touch.clientX - touchStart.x) +
              Math.abs(touch.clientY - touchStart.y) > 8) {
        clearTimeout(touchLongPressTimer);
      }
      return;
    }
    // The gesture recognizer has already claimed this touch sequence, so a
    // move after the long press adjusts the selected range.
    var current = rangeAt(touch.clientX, touch.clientY);
    if (current && touchAnchor) selectFrom(touchAnchor, current);
  }, true);

  function endTouch() {
    clearTimeout(touchLongPressTimer);
    if (touchLongPressFired && touchLast) {
      // Wait until the finger is up so the menu uses the final selection.
      postMenu(touchLast.x, touchLast.y);
    }
    touchStart = null;
    touchLast = null;
    touchAnchor = null;
    touchLongPressFired = false;
  }

  document.addEventListener('touchend', endTouch, true);
  document.addEventListener('touchcancel', endTouch, true);

  document.addEventListener('contextmenu', function (e) {
    if (e.button === 0) selectWordAt(e.clientX, e.clientY);
  }, true);
})();
""";
}

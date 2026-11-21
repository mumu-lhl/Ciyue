/// Mouse text-selection fallback for the Linux/Windows WebViews.
///
/// WPE on KDE does not always turn pointer motion into a DOM selection, and it
/// can drop the word selection made by a double click on mouse up. This script
/// builds mouse selections from `caretRangeFromPoint` itself:
///
/// * left drag extends from the press point to the current point;
/// * a 400 ms left press-and-hold selects the word under the pointer;
/// * double-click and long-press selections are restored if the engine clears
///   them on release.
///
/// It never cancels an event, so the engine's own selection and the app's
/// context-menu/rocker handlers keep working. Touch input is deliberately left
/// to the engine and to [DictionarySelectionGestureRecognizer].
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
    }, 400);
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
})();
""";
}

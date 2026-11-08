import "dart:convert";

/// The right-click menu injected on Windows and Linux only.
///
/// WebView2 and WPE both show a bare engine menu (Copy / Inspect Element), and
/// neither offers the app's own actions. Their engine menu is disabled in the
/// WebView settings and the app draws a Flutter one instead; this script
/// reports the pointer position and the word under it through the key bridge.
///
/// macOS never loads this script: WKWebView's own menu is richer and offers
/// the system dictionary services, so it is left exactly as it was.
///
/// A right click that is part of a rocker gesture (left button held) belongs
/// to `gestureScript` and is not reported here.
String desktopContextMenuScript() {
  return """
(function () {
  function post(payload) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('ciyueKey', 'DesktopContextMenu', payload);
    }
  }

  var leftDown = false;

  // Keep the reader's own selection when the click lands inside it, so Copy
  // and the lookups use the whole phrase rather than a single word. Otherwise
  // select the word under the pointer with the browser's own granularity,
  // which also copes with languages that do not separate words with spaces.
  function wordAt(x, y) {
    var selection = window.getSelection();
    if (selection && selection.rangeCount > 0) {
      var text = selection.toString().trim();
      if (text) {
        var rects = selection.getRangeAt(0).getClientRects();
        for (var i = 0; i < rects.length; i++) {
          var r = rects[i];
          if (x >= r.left && x <= r.right && y >= r.top && y <= r.bottom) {
            return text;
          }
        }
      }
    }
    if (!document.caretRangeFromPoint || !selection) return '';
    var range = document.caretRangeFromPoint(x, y);
    if (!range) return '';
    selection.removeAllRanges();
    selection.addRange(range);
    if (selection.modify) {
      selection.modify('move', 'backward', 'word');
      selection.modify('extend', 'forward', 'word');
    }
    return selection.toString().trim();
  }

  document.addEventListener('mousedown', function (e) {
    if (e.button === 0) leftDown = true;
    if (e.button !== 2 || leftDown) return;
    post(JSON.stringify({
      x: e.clientX,
      y: e.clientY,
      word: wordAt(e.clientX, e.clientY)
    }));
  }, true);

  document.addEventListener('mouseup', function (e) {
    if (e.button === 0) leftDown = false;
  }, true);

  // The engine menu is already disabled in the WebView settings. Keep this
  // guard for engines that still dispatch contextmenu; a rocker gesture has
  // its own handler in gestureScript and is unaffected.
  document.addEventListener('contextmenu', function (e) {
    e.preventDefault();
    e.stopPropagation();
  }, true);
})();
""";
}

/// The pointer position (WebView CSS pixels) and the word it selected.
class DesktopContextMenuRequest {
  final double x;
  final double y;
  final String word;

  const DesktopContextMenuRequest({
    required this.x,
    required this.y,
    required this.word,
  });
}

/// Decodes a `DesktopContextMenu` bridge message, or returns null for a
/// payload the script could not have produced.
DesktopContextMenuRequest? parseDesktopContextMenu(String payload) {
  try {
    final map = jsonDecode(payload);
    if (map is! Map<String, dynamic>) return null;
    final x = map["x"];
    final y = map["y"];
    final word = map["word"];
    if (x is! num || y is! num || !x.isFinite || !y.isFinite) return null;
    if (word != null && word is! String) return null;
    return DesktopContextMenuRequest(
      x: x.toDouble(),
      y: y.toDouble(),
      word: (word as String? ?? "").trim(),
    );
  } catch (_) {
    return null;
  }
}

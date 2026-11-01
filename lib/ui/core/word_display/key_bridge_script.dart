/// Forwards the keys that the WebView would otherwise swallow.
///
/// A WebView that holds the native focus does not let Flutter see key events,
/// so the keys that must work while an entry is being read are handled here
/// and handed over to Dart through the `ciyueKey` handler.
///
/// * `Enter` looks up the selected text. Like EBWin, this works for any
///   selection, which matters for the languages that do not separate words
///   with spaces: double-clicking only ever selects one part of a German
///   compound or a Japanese phrase, while selecting the whole phrase gets
///   the full form.
/// * The zoom keys are taken over from the engine. It zooms the page on its
///   own for them, which leaves the entry scrolling sideways; the app's own
///   zoom keeps the text and the images in step instead.
String keyBridgeScript() {
  return """
(function () {
  function post(name, payload) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('ciyueKey', name, payload || '');
    }
  }

  document.addEventListener('keydown', function (e) {
    if (e.ctrlKey && !e.altKey && !e.metaKey) {
      var key = e.key;
      if (key === '=' || key === '+' || key === '-' || key === '0') {
        // The engine zooms the page for these before they reach anybody
        // else, so they have to be caught here.
        e.preventDefault();
        post('Zoom', key);
        return;
      }
    }

    var target = e.target;
    var tag = target && target.tagName ? target.tagName.toLowerCase() : '';
    var inInput = tag === 'input' || tag === 'textarea' || (target && target.isContentEditable);

    // Enter belongs to the input the user is typing in.
    if (e.key === 'Enter') {
      if (inInput) return;
      var selection = window.getSelection();
      var text = selection ? selection.toString().trim() : '';
      if (!text) return;
      e.preventDefault();
      post('Enter', text);
    }
  }, true);
})();
""";
}

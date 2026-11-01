/// Forwards the keys that the WebView would otherwise swallow.
///
/// A WebView that holds the native focus does not let Flutter see key
/// events, so the shortcuts that must work while an entry is being read are
/// handled here and handed over to Dart through the `ciyueKey` handler.
///
/// * `Enter` looks up the selected text. Like EBWin, this works for any
///   selection, which matters for the languages that do not separate words
///   with spaces: double-clicking only ever selects one part of a German
///   compound or a Japanese phrase, while selecting the whole phrase gets
///   the full form.
/// * The zoom keys are taken over from the engine. It zooms the page on its
///   own for them, which leaves the entry scrolling sideways; the app's own
///   zoom keeps the text and the images in step instead.
/// * `Esc` and the app's other shortcuts are forwarded as they are, so the
///   bridge and the Flutter focus tree run the same table.
String keyBridgeScript() {
  return """
(function () {
  function post(name, payload) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('ciyueKey', name, payload || '');
    }
  }
  // The combinations the app binds behind the entry. Only these are taken
  // from the WebView, so Ctrl+C and the other browser keys keep working.
  var shortcuts = [
    ['Escape', false, false, false],
    ['KeyF', true, false, false],
    ['KeyT', true, false, false],
    ['KeyW', true, false, false],
    ['KeyR', true, false, false],
    ['KeyS', true, false, true],
    ['Tab', true, false, false],
    ['Tab', true, false, true],
    ['PageUp', true, false, false],
    ['PageDown', true, false, false],
    ['PageUp', false, false, false],
    ['PageDown', false, false, false],
    ['ArrowUp', true, false, false],
    ['ArrowDown', true, false, false],
    ['Backquote', true, false, false]
  ];
  for (var n = 0; n <= 9; n++) {
    shortcuts.push(['Digit' + n, true, false, false]);
    shortcuts.push(['Digit' + n, false, true, false]);
  }
  function shortcutFor(e) {
    for (var i = 0; i < shortcuts.length; i++) {
      var s = shortcuts[i];
      if (s[0] === e.code && s[1] === e.ctrlKey && s[2] === e.altKey && s[3] === e.shiftKey) {
        return {
          code: e.code,
          key: e.key,
          ctrl: e.ctrlKey,
          alt: e.altKey,
          shift: e.shiftKey,
          meta: e.metaKey
        };
      }
    }
    return null;
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
      return;
    }

    if (inInput) return;
    var combo = shortcutFor(e);
    if (!combo) return;
    // The plain PageUp/PageDown keys are the WebView's own scrolling keys.
    // They are forwarded so that the expansion layout can page the entry,
    // but the WebView keeps them: in the tab layout it is the one that
    // scrolls, and taking the keys away would freeze the entry.
    var keepsWebViewScroll =
      !e.ctrlKey && !e.altKey && !e.metaKey &&
      (e.code === 'PageUp' || e.code === 'PageDown');
    if (!keepsWebViewScroll) {
      e.preventDefault();
    }
    post('Shortcut', JSON.stringify(combo));
  }, true);
})();
""";
}

/// Selects the word under the pointer on a right click and tells Dart which
/// word it was.
///
/// A right click does not raise the long press selection, so the context menu
/// had nothing to look up. The word is both selected (the menu's Copy and Read
/// aloud use it) and handed over as `ContextWord`, so the lookup still works
/// when the native menu clears the selection. The word granularity is the
/// browser's own, which also copes with the languages that do not separate
/// words with spaces.
String contextWordScript() {
  return """
(function () {
  function postWord(word) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('ciyueKey', 'ContextWord', word || '');
    }
  }
  function selectWordAt(x, y) {
    if (!document.caretRangeFromPoint) return '';
    var range = document.caretRangeFromPoint(x, y);
    if (!range) return '';
    var selection = window.getSelection();
    if (!selection) return '';
    selection.removeAllRanges();
    selection.addRange(range);
    if (selection.modify) {
      selection.modify('move', 'backward', 'word');
      selection.modify('extend', 'forward', 'word');
    }
    return selection.toString().trim();
  }
  function takeWord(x, y) {
    postWord(selectWordAt(x, y));
  }
  // pointerdown and mousedown fire before the native menu and carry the
  // button, so the word is known by the time the menu asks for it.
  document.addEventListener('pointerdown', function (e) {
    if (e.button === 2) takeWord(e.clientX, e.clientY);
  }, true);
  document.addEventListener('mousedown', function (e) {
    if (e.button === 2) takeWord(e.clientX, e.clientY);
  }, true);
  // Fallback for a WebView that only dispatches contextmenu.
  document.addEventListener('contextmenu', function (e) {
    var selection = window.getSelection();
    if (!selection || selection.toString().trim() === '') {
      takeWord(e.clientX, e.clientY);
    }
  }, true);
})();
""";
}

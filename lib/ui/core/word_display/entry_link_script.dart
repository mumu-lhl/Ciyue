/// Dictionary links are **not** URIs: dictionary ids, entry ids and tag names
/// may contain `:`, `@`, `#` or upper-case ASCII, all of which a URI parser
/// mangles (`entry://tag:x` throws, `entry://@id` drops the `@`, `entry://W`
/// lower-cases the host). Before a link is followed, the word is therefore
/// decoded once and re-encoded byte by byte, so the navigation URL survives
/// parsing and the Dart side decodes it back to the original string.
///
/// `bword://` (Babylon word links, used by クラウン独和) is mapped onto
/// `entry://`, and the anchor of a link is carried as a `?gdanchor=` query
/// item rather than a fragment: a `#` in the URL is read by the WebView as a
/// same-document position, so it would never reach the navigation handler.
/// A lone `#` separates the headword from its anchor and `##` escapes one
/// literal `#` (see `parseEntryLink` in `entry_anchor.dart`, which this script
/// mirrors).
const String _dictionaryEntryLinkScriptBody = r"""
// Whether the JS bridge (callHandler) is reachable. `dictionaryEntryLinkScript`
// rewrites the value of this declaration; the default keeps the script valid
// when it is injected without the flag, which is what the browser regression
// test does when it extracts this body verbatim.
var __CIYUE_BRIDGE__ = false;

function _extractWordFromHref(href) {
  if (!href) return null;
  var prefix = /^(?:entry|bword):\/\//i.exec(href);
  if (prefix) {
    return href.slice(prefix[0].length);
  }
  if (/^gdlookup:\/\/localhost\//i.test(href)) {
    var rest = href.slice('gdlookup://localhost/'.length);
    var query = rest.indexOf('?');
    return query >= 0 ? rest.slice(0, query) : rest;
  }
  return null;
}

function _extractSoundFromHref(href) {
  if (!href) return null;
  var m = /^sound:\/\//i.exec(href);
  if (!m) return null;
  var rest = href.slice(m[0].length);
  if (/^localhost\//i.test(rest)) rest = rest.slice('localhost/'.length);
  return rest;
}

function _decodeSoundFile(raw) {
  try {
    return decodeURIComponent(raw);
  } catch (e) {
    return raw;
  }
}

function _decodeWord(raw) {
  try {
    return decodeURIComponent(raw);
  } catch (e) {
    return raw;
  }
}

// Mirrors `parseEntryLink` in entry_anchor.dart: scanning left to right, `##`
// escapes one literal `#` and a lone `#` separates the headword from the
// anchor. Keep the two implementations in step.
function _parseLink(raw) {
  var text = raw || '';
  var word = '';
  var i = 0;
  while (i < text.length) {
    var ch = text.charAt(i);
    if (ch !== '#') {
      word += ch;
      i++;
      continue;
    }
    if (i + 1 < text.length && text.charAt(i + 1) === '#') {
      word += '#';
      i += 2;
      continue;
    }
    return { word: word, anchor: text.slice(i + 1) };
  }
  return { word: word, anchor: '' };
}

function _linkTarget(raw) {
  var parsed = _parseLink(raw);
  return {
    word: _decodeWord(parsed.word),
    anchor: parsed.anchor ? _decodeWord(parsed.anchor) : ''
  };
}

// Percent-encode every byte, ASCII letters included: that is what keeps
// `entry://Haus` from being lower-cased when the URI parser normalises the
// host, and what stops `:` or `@` from being read as port / userinfo.
function _encodedWord(word) {
  var bytes;
  try {
    bytes = new TextEncoder().encode(word);
  } catch (e) {
    return '';
  }
  var out = '';
  for (var i = 0; i < bytes.length; i++) {
    var hex = bytes[i].toString(16).toUpperCase();
    out += '%' + (hex.length < 2 ? '0' + hex : hex);
  }
  return out;
}

// The canonical href for a parsed link. An empty word with an anchor means
// "scroll the entry on screen", which never becomes a navigation.
function _targetHref(link) {
  var encoded = _encodedWord(link.word);
  if (!encoded) return '';
  var href = 'gdlookup://localhost/' + encoded;
  if (link.anchor) href += '?gdanchor=' + _encodedWord(link.anchor);
  return href;
}

function _scrollToAnchor(anchor) {
  if (!anchor) return false;
  var el = document.getElementById(anchor);
  if (!el) {
    var named = document.getElementsByName(anchor);
    el = named && named.length ? named[0] : null;
  }
  if (!el) return false;
  el.scrollIntoView({ block: 'start' });
  return true;
}

function _openWordInNewTab(word) {
  // This handler carries a word only, so a new tab opens the entry without
  // scrolling it; an anchor applies to in-place navigation only.
  if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
    window.flutter_inappwebview.callHandler('openInNewTab', word);
  } else {
    window.location.href = 'ciyue-open-new-tab://' + encodeURIComponent(word);
  }
}

// Plain left-click on a dictionary cross-reference, used only on the JS-bridge
// path (Windows). The single JSON argument matches the proven callHandler
// pattern (openInNewTab). When the bridge is unavailable the navigation falls
// back to a gdlookup:// URL that macOS/Linux intercept via
// shouldOverrideUrlLoading.
function _openEntry(word, anchor) {
  if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
    window.flutter_inappwebview.callHandler(
      'openEntry',
      JSON.stringify({ word: word, anchor: anchor || '' }),
    );
  } else {
    var target = _targetHref({ word: word, anchor: anchor || '' });
    if (target) window.location.href = target;
  }
}

// A pronunciation link plays its referenced audio resource through the JS
// bridge. There is no navigation fallback: sound:// playback only happens
// where the bridge or shouldOverrideUrlLoading is active, and those platforms
// expose callHandler.
function _playSoundResource(filename) {
  if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
    window.flutter_inappwebview.callHandler('playSoundResource', filename);
  }
}

document.addEventListener('mousedown', function (event) {
  if (event.button === 1) {
    const target = event.target;
    const anchor = target instanceof Element ? target.closest('a[href]') : null;
    if (anchor) {
      const href = anchor.getAttribute('href');
      if (_extractWordFromHref(href) !== null) {
        event.preventDefault();
      }
    }
  }
}, true);

document.addEventListener('click', function (event) {
  const target = event.target;
  const anchor = target instanceof Element ? target.closest('a[href]') : null;
  if (!anchor) return;
  const href = anchor.getAttribute('href');
  if (!href) return;

  // A pronunciation link plays its referenced audio resource. On the bridge
  // path (Windows) it is handled directly via callHandler; elsewhere the
  // sound:// navigation is left to proceed so shouldOverrideUrlLoading can
  // intercept it.
  const rawSound = _extractSoundFromHref(href);
  if (rawSound !== null) {
    const filename = _decodeSoundFile(rawSound);
    if (filename && __CIYUE_BRIDGE__) {
      event.preventDefault();
      event.stopPropagation();
      _playSoundResource(filename);
    }
    return;
  }

  const rawWord = _extractWordFromHref(href);
  if (rawWord === null) return;

  const link = _linkTarget(rawWord);

  // A link naming only an anchor scrolls the entry already on screen: there is
  // no word to look up and therefore no page to load.
  if (!link.word && link.anchor) {
    if (_scrollToAnchor(link.anchor)) {
      event.preventDefault();
      event.stopPropagation();
    }
    return;
  }

  if (event.ctrlKey || event.metaKey) {
    event.preventDefault();
    event.stopPropagation();
    _openWordInNewTab(link.word);
    return;
  }

  if (__CIYUE_BRIDGE__) {
    // Plain left-click on Windows: route through the JS bridge instead of
    // letting the navigation proceed to gdlookup://. The WebView2 plugin never
    // reports custom-scheme navigations to shouldOverrideUrlLoading, so a plain
    // navigation would silently do nothing.
    event.preventDefault();
    event.stopPropagation();
    _openEntry(link.word, link.anchor);
    return;
  }

  // Non-bridge platforms: let the navigation proceed so the native
  // shouldOverrideUrlLoading can intercept the custom-scheme URL.
  if (/^gdlookup:\/\/localhost\//i.test(href)) return;
  const newHref = _targetHref(link);
  if (newHref) {
    anchor.setAttribute('href', newHref);
  }
}, true);

document.addEventListener('auxclick', function (event) {
  if (event.button !== 1) return;
  const target = event.target;
  const anchor = target instanceof Element ? target.closest('a[href]') : null;
  if (!anchor) return;
  const href = anchor.getAttribute('href');
  const rawWord = _extractWordFromHref(href);
  if (rawWord !== null) {
    event.preventDefault();
    event.stopPropagation();
    _openWordInNewTab(_linkTarget(rawWord).word);
  }
}, true);

document.addEventListener('dragstart', function (event) {
  event.preventDefault();
}, true);

document.addEventListener('mousedown', function (event) {
  if (event.button === 0 && !event.shiftKey && !event.ctrlKey && !event.altKey && !event.metaKey && event.detail <= 1) {
    const sel = window.getSelection();
    if (sel && !sel.isCollapsed) {
      sel.removeAllRanges();
    }
  }
}, true);

// Rewrite `bword://` hrefs as the entry is parsed, instead of only when a
// click reaches the handlers above. A click can fail to reach them (an
// overlay element on top of the link, a tap that the WebView reads as a drag,
// a synthetic click from the dictionary's own script); the href would then
// stay `bword://`, a scheme the WebView has no handler for, and the tap would
// silently do nothing. Normalising up front also makes middle-click and link
// previews work.
(function () {
  function normalize(anchor) {
    var href = anchor.getAttribute && anchor.getAttribute('href');
    var prefix = href && /^bword:\/\//i.exec(href);
    if (!prefix) return;
    var link = _linkTarget(href.slice(prefix[0].length));
    // An anchor-only link stays as it is: the click handler scrolls the page
    // in place and there is no word to put in the path.
    if (!link.word) return;
    var target = _targetHref(link);
    if (target) anchor.setAttribute('href', target);
  }

  function scan(root) {
    if (!root || root.nodeType !== 1) return;
    if (root.tagName && root.tagName.toLowerCase() === 'a') normalize(root);
    if (!root.querySelectorAll) return;
    var anchors = root.querySelectorAll('a[href]');
    for (var i = 0; i < anchors.length; i++) normalize(anchors[i]);
  }

  var observer = new MutationObserver(function (records) {
    for (var i = 0; i < records.length; i++) {
      var added = records[i].addedNodes;
      for (var j = 0; j < added.length; j++) scan(added[j]);
    }
  });
  observer.observe(document, { childList: true, subtree: true });

  document.addEventListener('DOMContentLoaded', function () {
    scan(document.documentElement);
  });
})();

(function () {
  function injectNoDrag() {
    const root = document.head || document.documentElement;
    if (root && !document.getElementById('ciyue-no-drag')) {
      const style = document.createElement('style');
      style.id = 'ciyue-no-drag';
      style.textContent = '* { -webkit-user-drag: none !important; }';
      root.appendChild(style);
      return true;
    }
    return false;
  }
  if (!injectNoDrag()) {
    document.addEventListener('DOMContentLoaded', injectNoDrag);
  }
})();
""";

/// Dictionary entry-link click handling.
///
/// On Windows the WebView2 plugin never reports custom-scheme navigations
/// (`entry://`, `bword://`, `sound://`) to `shouldOverrideUrlLoading`, so plain
/// clicks must be routed through the `callHandler` JS bridge. On every other
/// platform the original navigation-based interception still works and is left
/// untouched. [useBridge] selects which behaviour the injected script uses;
/// [dictionaryUserScripts] passes `Platform.isWindows`.
///
/// The flag is declared inside the script body so that the body stays valid
/// JavaScript on its own; only its value is rewritten here.
String dictionaryEntryLinkScript({bool useBridge = false}) {
  return _dictionaryEntryLinkScriptBody.replaceFirst(
    "var __CIYUE_BRIDGE__ = false;",
    "var __CIYUE_BRIDGE__ = $useBridge;",
  );
}

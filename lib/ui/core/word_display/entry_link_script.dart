/// Dictionary links are **not** URIs: dictionary ids, entry ids and tag names
/// may contain `:`, `@`, `#` or upper-case ASCII, all of which a URI parser
/// mangles (`entry://tag:x` throws, `entry://@id` drops the `@`, `entry://W`
/// lower-cases the host). Before a link is followed, the word is therefore
/// decoded once and re-encoded byte by byte, so the navigation URL survives
/// parsing and the Dart side decodes it back to the original string.
///
/// `bword://` (Babylon word links, used by クラウン独和) is mapped onto
/// `entry://`, and `#anchors` are dropped: Ciyue looks up words, not positions
/// inside an entry.
const dictionaryEntryLinkScript = r"""
function _extractWordFromHref(href) {
  if (!href) return null;
  var prefix = /^(?:entry|bword):\/\//i.exec(href);
  if (prefix) {
    return href.slice(prefix[0].length);
  }
  if (/^gdlookup:\/\/localhost\//i.test(href)) {
    return href.slice('gdlookup://localhost/'.length);
  }
  return null;
}

function _decodeWord(raw) {
  try {
    return decodeURIComponent(raw);
  } catch (e) {
    return raw;
  }
}

// Anchors point at a position inside an entry; Ciyue has no scrolling target.
function _wordText(raw) {
  var word = raw || '';
  var hash = word.indexOf('#');
  if (hash >= 0) word = word.slice(0, hash);
  return _decodeWord(word);
}

// Percent-encode every byte, ASCII letters included: that is what keeps
// `entry://Haus` from being lower-cased when the URI parser normalises the
// host, and what stops `:` or `@` from being read as port / userinfo.
function _encodedWord(raw) {
  var word = _wordText(raw);
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

function _openWordInNewTab(word) {
  if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
    window.flutter_inappwebview.callHandler('openInNewTab', word);
  } else {
    window.location.href = 'ciyue-open-new-tab://' + encodeURIComponent(word);
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
  const rawWord = _extractWordFromHref(href);
  if (rawWord === null) return;

  if (event.ctrlKey || event.metaKey) {
    event.preventDefault();
    event.stopPropagation();
    _openWordInNewTab(_wordText(rawWord));
    return;
  }

  // Already canonical: the word sits in the path, so let the navigation
  // proceed untouched.
  if (/^gdlookup:\/\/localhost\//i.test(href)) return;

  // Rewrite the href in place and let the navigation proceed: the Dart side
  // then receives a URI-safe URL and decodes it back. The word goes into the
  // path, not the host: a host is folded to lower case by the URL parser, so
  // `entry://Abend` arrives as `abend` and every link to a capitalised
  // headword lands on the wrong entry (or nowhere).
  const encoded = _encodedWord(rawWord);
  if (encoded) {
    anchor.setAttribute('href', 'gdlookup://localhost/' + encoded);
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
    _openWordInNewTab(_wordText(rawWord));
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
    var encoded = _encodedWord(href.slice(prefix[0].length));
    if (encoded) anchor.setAttribute('href', 'gdlookup://localhost/' + encoded);
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

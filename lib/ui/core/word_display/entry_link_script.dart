/// Chromium can truncate unescaped Unicode in custom-scheme navigation before
/// shouldOverrideUrlLoading receives it. Encode only non-ASCII characters so
/// existing percent escapes, case, and URL delimiters remain unchanged.
const dictionaryEntryLinkScript = r"""
function _extractWordFromHref(href) {
  if (!href) return null;
  if (/^entry:\/\//i.test(href)) {
    return href.slice('entry://'.length);
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
  if (!href) return;

  if (event.ctrlKey || event.metaKey) {
    const rawWord = _extractWordFromHref(href);
    if (rawWord !== null) {
      event.preventDefault();
      event.stopPropagation();
      _openWordInNewTab(_decodeWord(rawWord));
      return;
    }
  }

  if (!/^(?:entry:\/\/|gdlookup:\/\/localhost\/)/i.test(href)) return;
  const encoded = href.replace(/[^\x00-\x7F]+/gu, function (text) {
    return encodeURI(text);
  });
  if (encoded !== href) anchor.setAttribute('href', encoded);
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
    _openWordInNewTab(_decodeWord(rawWord));
  }
}, true);
""";

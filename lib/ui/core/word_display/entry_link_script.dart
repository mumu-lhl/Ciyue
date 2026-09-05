/// Chromium can truncate unescaped Unicode in custom-scheme navigation before
/// shouldOverrideUrlLoading receives it. Encode only non-ASCII characters so
/// existing percent escapes, case, and URL delimiters remain unchanged.
const dictionaryEntryLinkScript = r"""
document.addEventListener('click', function (event) {
  const target = event.target;
  const anchor = target instanceof Element ? target.closest('a[href]') : null;
  if (!anchor) return;
  const href = anchor.getAttribute('href');
  if (!/^entry:\/\//i.test(href)) return;
  const encoded = href.replace(/[^\x00-\x7F]+/gu, function (text) {
    return encodeURI(text);
  });
  if (encoded !== href) anchor.setAttribute('href', encoded);
}, true);
""";

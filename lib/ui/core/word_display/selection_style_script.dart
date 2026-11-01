/// Makes the selected text visible.
///
/// A dictionary's own stylesheet can leave the selection the same colour as
/// the background, which makes it look as if the text could not be selected
/// at all. The highlight is drawn over whatever the entry looks like, so it
/// shows up in every theme.
String selectionStyleScript() {
  return """
(function () {
  const apply = function () {
    const root = document.head || document.documentElement;
    if (!root) return false;
    let style = document.getElementById('ciyue-selection-style');
    if (!style) {
      style = document.createElement('style');
      style.id = 'ciyue-selection-style';
      root.appendChild(style);
    }
    style.textContent = '::selection { background: rgba(64, 128, 255, 0.45); }';
    return true;
  };
  if (!apply()) {
    const observer = new MutationObserver(function () {
      if (apply()) observer.disconnect();
    });
    observer.observe(document, { childList: true, subtree: true });
  }
})();
""";
}

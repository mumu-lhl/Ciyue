import "dart:async";

import "package:ciyue/repositories/settings.dart";

/// Zooms the dictionary entry content in or out.
void changeContentScale(Settings settings, double delta) {
  unawaited(settings.setContentScale(settings.contentScale + delta));
}

/// Puts the dictionary entry content back to its normal size.
void resetContentScale(Settings settings) {
  unawaited(settings.setContentScale(1.0));
}

/// Applies a zoom key that the entry's key bridge handed over.
///
/// The engine zooms the page on its own for these keys, which scrolls the
/// entry sideways, so they are caught before it gets to them.
void applyZoomKey(Settings settings, String key) {
  switch (key) {
    case "=":
    case "+":
      changeContentScale(settings, 0.1);
      break;
    case "-":
      changeContentScale(settings, -0.1);
      break;
    case "0":
      resetContentScale(settings);
      break;
  }
}

/// Applies the entry zoom level to the page.
///
/// `zoom` is used rather than `transform: scale()` because it takes part in
/// layout: text and images grow together and the content still fits the
/// viewport instead of overflowing it. The value goes onto the root element
/// as an inline style, so it wins over the stylesheet the dictionary ships
/// with without having to share the `<style>` element the custom CSS uses.
///
/// The script exposes `window.ciyueSetZoom` so the scale can be changed
/// without reloading the page, and applies the value right away so the first
/// paint is already zoomed.
String contentScaleScript(double scale) {
  final value = scale.toStringAsFixed(3);
  return """
(function () {
  var scale = $value;
  function apply(v) {
    var root = document.documentElement;
    if (!root) return false;
    root.style.zoom = v;
    return true;
  }
  window.ciyueSetZoom = function (v) {
    if (v === null || v === undefined || isNaN(v)) return;
    apply(v);
  };
  if (!apply(scale)) {
    var observer = new MutationObserver(function () {
      if (apply(scale)) observer.disconnect();
    });
    observer.observe(document, { childList: true, subtree: true });
  }
})();
""";
}

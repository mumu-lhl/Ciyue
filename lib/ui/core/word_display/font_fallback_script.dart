import "dart:convert";

import "package:ciyue/ui/core/font_fallback.dart";

/// Injects a font stack for characters the dictionary's own font (or the
/// default CJK font) does not cover, e.g. IPA transcriptions such as `ɡədɪ́çt`.
///
/// Dictionaries commonly set `font-family` on individual spans and sometimes
/// replace stylesheets after load, so appending to every declaration is more
/// reliable than only setting a family on `body`.
String fontFallbackScript() {
  final fallback = jsonEncode(ipaFontFallbackCss);
  return """
(function() {
  var fallback = $fallback;
  var marker = "DejaVu Sans";

  function patchStyle(style) {
    if (!style) return;
    var family = style.getPropertyValue("font-family");
    if (!family || family.indexOf(marker) !== -1) return;
    style.setProperty(
      "font-family",
      family + ", " + fallback,
      style.getPropertyPriority("font-family")
    );
  }

  function patchRules(rules) {
    if (!rules) return;
    for (var i = 0; i < rules.length; i++) {
      var rule = rules[i];
      try {
        if (rule.cssRules) patchRules(rule.cssRules);
        patchStyle(rule.style);
      } catch (e) {
        // Cross-origin stylesheet rules cannot be read.
      }
    }
  }

  function patchSheets() {
    for (var i = 0; i < document.styleSheets.length; i++) {
      try {
        patchRules(document.styleSheets[i].cssRules);
      } catch (e) {}
    }
  }

  function patchElement(element) {
    if (element && element.style) patchStyle(element.style);
  }

  function patchAll() {
    patchSheets();
    var styled = document.querySelectorAll("[style]");
    for (var i = 0; i < styled.length; i++) patchElement(styled[i]);
  }

  patchAll();
  if (document.readyState !== "complete") {
    document.addEventListener("DOMContentLoaded", patchAll, { once: true });
    window.addEventListener("load", patchAll, { once: true });
  }

  new MutationObserver(function(mutations) {
    var sheetsChanged = false;
    for (var i = 0; i < mutations.length; i++) {
      var mutation = mutations[i];
      if (mutation.type === "attributes") {
        patchElement(mutation.target);
      } else if (mutation.type === "characterData") {
        sheetsChanged = true;
      } else if (mutation.type === "childList") {
        sheetsChanged = true;
        for (var j = 0; j < mutation.addedNodes.length; j++) {
          var node = mutation.addedNodes[j];
          if (node.nodeType !== 1) continue;
          patchElement(node);
          var children = node.querySelectorAll
              ? node.querySelectorAll("[style]")
              : [];
          for (var k = 0; k < children.length; k++) patchElement(children[k]);
        }
      }
    }
    if (sheetsChanged) patchSheets();
  }).observe(document, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["style"],
    characterData: true
  });
})();
""";
}

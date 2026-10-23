import "dart:convert";

import "package:dict_reader/dict_reader.dart";
import "package:xml/xml.dart";

/// Converts StarDict entry fields into the HTML fragment the word display
/// renders, mirroring how MDX entries are already HTML.
///
/// Field handling by StarDict type code:
/// - `h`: HTML, passed through unchanged.
/// - `x`: XDXF XML, converted by [xdxfToHtml].
/// - `g`: Pango markup, converted by [pangoToHtml].
/// - `t`: phonetics, shown as a bracketed line.
/// - `m`, `l`, `y`, `k`, `n` and any other text type: escaped plain text
///   with line breaks preserved.
/// - Binary fields (uppercase types such as `W`/`P`): skipped; the media
///   bytes are not inlined into the page.
String stardictEntryToHtml(List<StarDictField> fields) {
  final buffer = StringBuffer();
  for (final field in fields) {
    final text = field.text;
    if (text == null) continue;
    switch (field.type) {
      case "h":
        buffer.write(text);
      case "x":
        buffer.write(xdxfToHtml(text));
      case "g":
        buffer.write('<div class="sd-g">${pangoToHtml(text)}</div>');
      case "t":
        buffer.write(
          '<div class="sd-t">[${const HtmlEscape().convert(text)}]</div>',
        );
      default:
        buffer.write('<div class="sd-text">${_plainTextToHtml(text)}</div>');
    }
  }
  return buffer.toString();
}

String _plainTextToHtml(String text) {
  return const HtmlEscape()
      .convert(text)
      .replaceAll("\r\n", "<br>")
      .replaceAll("\n", "<br>");
}

/// Converts Pango markup (a small XML dialect) to HTML. Only the inline
/// formatting Pango defines is carried over; `span` attributes other than
/// foreground/background colors are dropped. Unparseable input falls back
/// to escaped plain text.
String pangoToHtml(String markup) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse("<root>$markup</root>");
  } on XmlException {
    return _plainTextToHtml(markup);
  }
  final buffer = StringBuffer();
  _writePangoNodes(document.rootElement.children, buffer);
  return buffer.toString();
}

void _writePangoNodes(List<XmlNode> nodes, StringBuffer buffer) {
  const passthrough = {"b", "i", "u", "s", "tt", "sup", "sub", "small"};
  for (final node in nodes) {
    if (node is XmlText) {
      buffer.write(const HtmlEscape().convert(node.value));
      continue;
    }
    if (node is! XmlElement) continue;
    final name = node.name.local;
    if (passthrough.contains(name)) {
      buffer.write("<$name>");
      _writePangoNodes(node.children, buffer);
      buffer.write("</$name>");
    } else if (name == "big") {
      buffer.write('<span style="font-size:larger">');
      _writePangoNodes(node.children, buffer);
      buffer.write("</span>");
    } else if (name == "span") {
      final styles = <String>[];
      final foreground = node.getAttribute("foreground");
      if (foreground != null) styles.add("color:$foreground");
      final background = node.getAttribute("background");
      if (background != null) styles.add("background-color:$background");
      buffer.write(
        styles.isEmpty ? "<span>" : '<span style="${styles.join(";")}">',
      );
      _writePangoNodes(node.children, buffer);
      buffer.write("</span>");
    } else {
      _writePangoNodes(node.children, buffer);
    }
  }
}

/// Parses XDXF content and returns its root element, or null when the
/// content is not parseable XML at all. Some dictionaries store only a
/// fragment (several top-level elements without an `<xdxf>` root), so a
/// failed parse is retried with the content wrapped in a synthetic root.
XmlElement? parseXdxfRoot(String xdxf) {
  try {
    return XmlDocument.parse(xdxf).rootElement;
  } on XmlException {
    try {
      return XmlDocument.parse("<xdxf>$xdxf</xdxf>").rootElement;
    } on XmlException {
      return null;
    }
  }
}

/// Converts an XDXF article to HTML.
///
/// The mapping keeps the article's structure visible without a stylesheet:
/// definitions become blocks, examples are grouped with their translation,
/// grammar/transcription/comment spans get classes the dictionary CSS can
/// target, and `<kref>` cross-references become `entry://` links the word
/// display already intercepts for navigation.
String xdxfToHtml(String xdxf) {
  final root = parseXdxfRoot(xdxf);
  if (root == null) {
    return '<div class="sd-text">${_plainTextToHtml(xdxf)}</div>';
  }
  final buffer = StringBuffer();
  _writeXdxfNodes(root.children, buffer);
  return buffer.toString();
}

void _writeXdxfNodes(List<XmlNode> nodes, StringBuffer buffer) {
  for (final node in nodes) {
    if (node is XmlText) {
      buffer.write(const HtmlEscape().convert(node.value));
      continue;
    }
    if (node is! XmlElement) continue;
    switch (node.name.local) {
      case "k":
        buffer.write('<div class="sd-k"><b>');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</b></div>");
      case "def":
        buffer.write('<div class="sd-def">');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</div>");
      case "gr":
        buffer.write('<span class="sd-gr"><i>');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</i></span>");
      case "tr":
        buffer.write('<span class="sd-tr">[');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("]</span>");
      case "dtrn":
        _writeXdxfNodes(node.children, buffer);
      case "ex":
        buffer.write('<div class="sd-ex">');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</div>");
      case "exorig":
        buffer.write('<span class="sd-exorig">');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</span> ");
      case "extr":
        buffer.write('<span class="sd-extr">');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</span>");
      case "co":
        buffer.write('<span class="sd-co">');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</span>");
      case "abbr":
        buffer.write('<span class="sd-abbr"><i>');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</i></span>");
      case "c":
        final color = node.getAttribute("color");
        buffer.write(color == null ? "<span>" : '<span style="color:$color">');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</span>");
      case "b" || "i" || "sup" || "sub":
        final name = node.name.local;
        buffer.write("<$name>");
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</$name>");
      case "kref":
        final word = node.innerText.trim();
        buffer.write(
          '<a href="entry://${Uri.encodeComponent(word)}">'
          "${const HtmlEscape().convert(word)}</a>",
        );
      case "iref":
        final href = node.getAttribute("href") ?? "";
        buffer.write('<a href="${const HtmlEscape().convert(href)}">');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</a>");
      case "rref":
        // Resource reference: an image in the dictionary's res/ folder is
        // served by the dictionary's local server; other resources are not
        // rendered inline.
        final file = node.innerText.trim();
        if (RegExp(
          r"\.(png|jpe?g|gif|svg|bmp)$",
          caseSensitive: false,
        ).hasMatch(file)) {
          buffer.write(
            '<img src="res/${const HtmlEscape().convert(file)}" '
            'alt="${const HtmlEscape().convert(file)}">',
          );
        }
      case "sr":
        buffer.write('<div class="sd-sr">');
        _writeXdxfNodes(node.children, buffer);
        buffer.write("</div>");
      default:
        _writeXdxfNodes(node.children, buffer);
    }
  }
}

import "dart:io";
import "dart:typed_data";

import "package:ciyue/services/stardict_html.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:dict_reader/dict_reader.dart";
import "package:material_ui/material_ui.dart";
import "package:path/path.dart" as p;
import "package:xml/xml.dart";

/// One StarDict entry prepared for native rendering: the headword plus the
/// structured fields the reader decoded for it.
class StardictNativeEntry {
  final String headword;
  final List<StarDictField> fields;

  const StardictNativeEntry({required this.headword, required this.fields});
}

/// Renders StarDict entries with native widgets instead of a WebView.
///
/// XDXF articles, Pango markup and the plain-text field types map onto
/// text spans and blocks styled from the app theme, so entries follow the
/// app's font, colors and text scaling, and cross-references navigate
/// through the same path the WebView's `entry://` links use. Entries
/// containing HTML fields never reach this widget: the word display falls
/// back to the WebView for the whole dictionary section in that case.
class StardictEntryListView extends StatelessWidget {
  final List<StardictNativeEntry> entries;
  final String resourceDirectory;
  final int dictId;
  final bool isExpansion;

  /// Resolves a resource file name (as referenced by an entry) to its
  /// bytes, consulting the `res/` directory and any `res.zip` archive.
  /// When null, images are read from `res/` files only, as before.
  final Future<Uint8List?> Function(String file)? resourceResolver;

  /// Zooms the entry. Every size in the native renderer is derived from one
  /// base size, so scaling that one scales the whole entry.
  final double scale;

  const StardictEntryListView({
    super.key,
    required this.entries,
    required this.resourceDirectory,
    required this.dictId,
    required this.isExpansion,
    this.resourceResolver,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          _EntryBlock(
            entry: entries[i],
            resourceDirectory: resourceDirectory,
            dictId: dictId,
            resourceResolver: resourceResolver,
            scale: scale,
          ),
        ],
      ],
    );
    if (isExpansion) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: content,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }
}

class _EntryBlock extends StatelessWidget {
  final StardictNativeEntry entry;
  final String resourceDirectory;
  final int dictId;
  final Future<Uint8List?> Function(String file)? resourceResolver;
  final double scale;

  const _EntryBlock({
    required this.entry,
    required this.resourceDirectory,
    required this.dictId,
    this.resourceResolver,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final renderer = _Renderer(
      context: context,
      resourceDirectory: resourceDirectory,
      dictId: dictId,
      resourceResolver: resourceResolver,
      scale: scale,
    );
    final blocks = <Widget>[];
    for (final field in entry.fields) {
      final text = field.text;
      if (text == null) continue; // Binary fields are not displayable.
      switch (field.type) {
        case "x":
          blocks.addAll(renderer.xdxfBlocks(text));
        case "g":
          blocks.add(renderer.pangoBlock(text));
        case "t":
          blocks.add(renderer.phonetic("[$text]"));
        default:
          // m, l, y and the other text types render as plain paragraphs.
          blocks.add(renderer.paragraph(text));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          blocks[i],
        ],
      ],
    );
  }
}

/// Builds the widgets and spans for one entry. Holds the build context so
/// the recursive XDXF/Pango walkers can resolve theme styles.
class _Renderer {
  final BuildContext context;
  final String resourceDirectory;
  final int dictId;
  final Future<Uint8List?> Function(String file)? resourceResolver;

  /// Zooms the entry. Every size below is derived from one base size, so
  /// scaling that one scales the whole entry.
  final double scale;

  _Renderer({
    required this.context,
    required this.resourceDirectory,
    required this.dictId,
    this.resourceResolver,
    this.scale = 1.0,
  });

  ThemeData get _theme => Theme.of(context);
  TextStyle get _body {
    final base = _theme.textTheme.bodyMedium ?? const TextStyle();
    if (scale == 1.0) return base;
    return base.copyWith(fontSize: (base.fontSize ?? 14) * scale);
  }

  TextStyle get _variant =>
      _body.copyWith(color: _theme.colorScheme.onSurfaceVariant);

  Widget paragraph(String text) => SelectableText(text, style: _body);

  Widget phonetic(String text) => SelectableText(text, style: _variant);

  // --- XDXF ---------------------------------------------------------------

  List<Widget> xdxfBlocks(String xdxf) {
    final root = parseXdxfRoot(xdxf);
    if (root == null) return [paragraph(xdxf)];
    return _xdxfBlockWidgets(root.children);
  }

  /// Block-level walk: inline runs become rich-text paragraphs; block
  /// elements (headword, definition, example, see-also) become their own
  /// widgets.
  List<Widget> _xdxfBlockWidgets(List<XmlNode> nodes) {
    final widgets = <Widget>[];
    var spans = <InlineSpan>[];
    void flush() {
      if (spans.isEmpty) return;
      widgets.add(SelectableText.rich(TextSpan(children: spans), style: _body));
      spans = <InlineSpan>[];
    }

    for (final node in nodes) {
      if (node is XmlElement) {
        switch (node.name.local) {
          case "k":
            flush();
            widgets.add(
              SelectableText(
                node.innerText.trim(),
                style: _theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
            continue;
          case "def":
            flush();
            widgets.addAll(_xdxfBlockWidgets(node.children));
            continue;
          case "ex":
            flush();
            widgets.add(_exampleBlock(node));
            continue;
          case "sr":
            flush();
            widgets.addAll(_xdxfBlockWidgets(node.children));
            continue;
        }
      }
      spans.addAll(_xdxfSpans([node], _body));
    }
    flush();
    return widgets;
  }

  Widget _exampleBlock(XmlElement node) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: _theme.colorScheme.primary, width: 2),
        ),
      ),
      child: SelectableText.rich(
        TextSpan(children: _xdxfSpans(node.children, _body)),
        style: _body,
      ),
    );
  }

  List<InlineSpan> _xdxfSpans(List<XmlNode> nodes, TextStyle base) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is XmlText) {
        if (node.value.isNotEmpty) spans.add(TextSpan(text: node.value));
        continue;
      }
      if (node is! XmlElement) continue;
      switch (node.name.local) {
        case "gr" || "co":
          spans.addAll(
            _xdxfSpans(
              node.children,
              base.copyWith(fontStyle: FontStyle.italic, color: _variant.color),
            ),
          );
        case "tr":
          spans.add(const TextSpan(text: "["));
          spans.addAll(_xdxfSpans(node.children, _variant));
          spans.add(const TextSpan(text: "]"));
        case "abbr":
          spans.addAll(
            _xdxfSpans(
              node.children,
              base.copyWith(fontStyle: FontStyle.italic),
            ),
          );
        case "c":
          final color = _parseColor(node.getAttribute("color"));
          spans.addAll(
            _xdxfSpans(
              node.children,
              color == null ? base : base.copyWith(color: color),
            ),
          );
        case "b":
          spans.addAll(
            _xdxfSpans(
              node.children,
              base.copyWith(fontWeight: FontWeight.bold),
            ),
          );
        case "i":
          spans.addAll(
            _xdxfSpans(
              node.children,
              base.copyWith(fontStyle: FontStyle.italic),
            ),
          );
        case "sup":
          spans.addAll(
            _xdxfSpans(
              node.children,
              base.copyWith(fontSize: (base.fontSize ?? 14) * 0.75),
            ),
          );
        case "sub":
          spans.addAll(
            _xdxfSpans(
              node.children,
              base.copyWith(fontSize: (base.fontSize ?? 14) * 0.75),
            ),
          );
        case "kref":
          final word = node.innerText.trim();
          if (word.isNotEmpty) {
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: () => handleOpenWordNavigation(
                    context,
                    word,
                    newTab: false,
                    dictId: dictId,
                  ),
                  child: Text(
                    word,
                    style: base.copyWith(
                      color: _theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            );
          }
        case "rref":
          final image = _resourceImage(node.innerText.trim());
          if (image != null) spans.add(image);
        case "exorig":
          spans.addAll(
            _xdxfSpans(
              node.children,
              base.copyWith(fontStyle: FontStyle.italic),
            ),
          );
        case "extr":
          spans.addAll(_xdxfSpans(node.children, _variant));
        default:
          spans.addAll(_xdxfSpans(node.children, base));
      }
    }
    return spans;
  }

  InlineSpan? _resourceImage(String file) {
    if (!RegExp(
      r"\.(png|jpe?g|gif|bmp|webp)$",
      caseSensitive: false,
    ).hasMatch(file)) {
      return null;
    }
    final resolver = resourceResolver;
    if (resolver != null) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260, maxWidth: 320),
          child: FutureBuilder<Uint8List?>(
            future: resolver(file),
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) return const SizedBox.shrink();
              return Image.memory(
                data,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              );
            },
          ),
        ),
      );
    }
    final candidate = p.normalize(p.join(resourceDirectory, "res", file));
    final resRoot = p.normalize(p.join(resourceDirectory, "res"));
    if (!p.isWithin(resRoot, candidate)) return null;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260, maxWidth: 320),
        child: Image.file(
          File(candidate),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  // --- Pango --------------------------------------------------------------

  Widget pangoBlock(String markup) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse("<root>$markup</root>");
    } on XmlException {
      return paragraph(markup);
    }
    return SelectableText.rich(
      TextSpan(children: _pangoSpans(document.rootElement.children, _body)),
      style: _body,
    );
  }

  List<InlineSpan> _pangoSpans(List<XmlNode> nodes, TextStyle base) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is XmlText) {
        if (node.value.isNotEmpty) spans.add(TextSpan(text: node.value));
        continue;
      }
      if (node is! XmlElement) continue;
      var style = base;
      switch (node.name.local) {
        case "b":
          style = base.copyWith(fontWeight: FontWeight.bold);
        case "i":
          style = base.copyWith(fontStyle: FontStyle.italic);
        case "u":
          style = base.copyWith(decoration: TextDecoration.underline);
        case "s":
          style = base.copyWith(decoration: TextDecoration.lineThrough);
        case "small":
          style = base.copyWith(fontSize: (base.fontSize ?? 14) * 0.85);
        case "big":
          style = base.copyWith(fontSize: (base.fontSize ?? 14) * 1.15);
        case "span":
          final color = _parseColor(node.getAttribute("foreground"));
          if (color != null) style = style.copyWith(color: color);
          if (node.getAttribute("font_style") == "italic" ||
              node.getAttribute("style") == "italic") {
            style = style.copyWith(fontStyle: FontStyle.italic);
          }
          if (node.getAttribute("font_weight") == "bold" ||
              node.getAttribute("weight") == "bold") {
            style = style.copyWith(fontWeight: FontWeight.bold);
          }
      }
      spans.add(
        TextSpan(
          style: style == base ? null : style,
          children: _pangoSpans(node.children, style),
        ),
      );
    }
    return spans;
  }

  Color? _parseColor(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final hex = raw.startsWith("#") ? raw.substring(1) : null;
    if (hex != null) {
      final value = int.tryParse(hex, radix: 16);
      if (value == null) return null;
      return Color(hex.length <= 6 ? 0xFF000000 | value : value);
    }
    return switch (raw.toLowerCase()) {
      "red" => const Color(0xFFF44336),
      "green" => const Color(0xFF4CAF50),
      "blue" => const Color(0xFF2196F3),
      "gray" || "grey" => const Color(0xFF9E9E9E),
      "purple" => const Color(0xFF9C27B0),
      "orange" => const Color(0xFFFF9800),
      "brown" => const Color(0xFF795548),
      _ => null,
    };
  }
}

/// Rewrites the `<audio>` / `<video>` markup that dictionary converters emit
/// into markup the word display can actually render and play.
///
/// pyglossary turns an MDict audio link
///
///     <a href="sound://audio/000000.mp3"><img class="audio" src="Audio.png"/></a>
///
/// into
///
///     <audio src="audio/000000.mp3"><img class="audio" src="Audio.png"/></audio>
///
/// which the WebView never shows: the children of `<audio>` are fallback
/// content that a browser supporting the element does not render, and an
/// `<audio>` without `controls` is not rendered at all. The speaker icon
/// therefore disappears and the clip cannot be clicked.
///
/// [rewriteMediaTags] reverses that transformation, putting the fallback
/// content back inside a real `<a>` that points at the `sound://` scheme the
/// word display intercepts. A `<video>` needs less: it is visible on its own,
/// so only a missing `controls` attribute keeps it from being playable.
library;

/// `<audio src="…">fallback</audio>`; group 2 is the source, group 3 the
/// fallback content. Extra attributes before `>` are tolerated.
final _audioTag = RegExp(
  r'''<\s*audio\s+src\s*=\s*(["'])([^"']+)\1[^>]*>(.*?)<\s*/\s*audio\s*>''',
  caseSensitive: false,
  dotAll: true,
);

/// The opening `<video …>` tag; group 1 holds its attributes.
final _videoTag = RegExp(r"<\s*video\b([^>]*)>", caseSensitive: false);

final _imgTag = RegExp(r"<\s*img\b", caseSensitive: false);

/// `controls` as a standalone attribute, not as part of a longer name.
final _controlsAttribute = RegExp(
  r"(?:^|\s)controls(?:\s|=|/|$)",
  caseSensitive: false,
);

/// Inline speaker glyph used when a converted `<audio>` carries no fallback
/// image of its own. Inline SVG keeps it theme-aware (`currentColor`) and
/// avoids shipping a new asset.
const _speakerIcon =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
    'width="1em" height="1em" fill="currentColor" '
    'style="vertical-align:middle" aria-hidden="true">'
    '<path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03'
    "v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 "
    '6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/>'
    "</svg>";

/// Rewrites audio/video tags in one dictionary entry's HTML.
///
/// A relative audio source becomes a `sound://` link, which
/// `normalizeDictionaryUrls` later normalises and the word display intercepts
/// to play the clip. A source that already carries a scheme (`http://`,
/// `sound://`, `data:`, …) is left untouched: it is not a dictionary
/// resource, so there is nothing for the app to resolve.
String rewriteMediaTags(String html) {
  if (html.isEmpty) return html;

  var result = html;

  if (result.toLowerCase().contains("<audio")) {
    result = result.replaceAllMapped(_audioTag, (match) {
      final src = match.group(2) ?? "";
      if (src.isEmpty || src.contains("://")) return match.group(0) ?? "";

      final fallback = match.group(3) ?? "";
      final content = _imgTag.hasMatch(fallback)
          ? fallback
          : "$fallback$_speakerIcon";
      return '<a href="sound://$src">$content</a>';
    });
  }

  if (result.toLowerCase().contains("<video")) {
    result = result.replaceAllMapped(_videoTag, (match) {
      final attributes = match.group(1) ?? "";
      // Already playable, or a closing `</video>` (which the pattern cannot
      // match, since its attributes would start with `/`).
      if (attributes.startsWith("/") ||
          _controlsAttribute.hasMatch(attributes)) {
        return match.group(0) ?? "";
      }
      return "<video$attributes controls>";
    });
  }

  return result;
}
